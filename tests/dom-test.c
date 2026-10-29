#include <libxml/parser.h>
#include <libxml/tree.h>

#include <assert.h>
#include <stdio.h>
#include <string.h>

static void assert_text(xmlNodePtr node, const char *expected) {
    xmlChar *content = xmlNodeGetContent(node);
    assert(content != NULL);
    assert(strcmp((const char *)content, expected) == 0);
    xmlFree(content);
}

static void test_constructors_and_root_replacement(void) {
    static const char input[] =
        "<!--before--><?before x?><old/><!--after--><?after y?>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr old_root;
    xmlNodePtr root;
    assert(doc != NULL);
    assert(strcmp((const char *)doc->version, "1.0") == 0);
    old_root = xmlDocGetRootElement(doc);
    root = xmlNewNode(NULL, BAD_CAST "new");
    assert(root != NULL);
    assert(xmlDocSetRootElement(doc, root) == old_root);
    assert(xmlDocGetRootElement(doc) == root);
    assert(root->parent == (xmlNodePtr)doc);
    assert(root->prev != NULL && root->prev->type == XML_PI_NODE);
    assert(root->next != NULL && root->next->type == XML_COMMENT_NODE);
    assert(root->next->next != NULL && root->next->next->type == XML_PI_NODE);
    assert(old_root->parent == NULL && old_root->next == NULL);
    xmlFreeNode(old_root);
    xmlFreeDoc(doc);

    doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    assert(doc != NULL);
    old_root = xmlDocGetRootElement(doc);
    xmlUnlinkNode(old_root);
    root = xmlNewNode(NULL, BAD_CAST "replacement");
    assert(root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(doc->children != root && doc->last == root);
    assert(root->parent == (xmlNodePtr)doc && root->prev != NULL);
    assert(root->prev->type == XML_PI_NODE);
    xmlFreeNode(old_root);
    xmlFreeDoc(doc);

    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "created");
    assert(doc != NULL && root != NULL);
    assert(strcmp((const char *)doc->version, "1.0") == 0);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlDocGetRootElement(doc) == root);
    {
        xmlNsPtr xml_ns = xmlSearchNs(doc, root, BAD_CAST "xml");
        assert(xml_ns != NULL);
        assert(strcmp((const char *)xml_ns->prefix, "xml") == 0);
        assert(strcmp((const char *)xml_ns->href,
                      "http://www.w3.org/XML/1998/namespace") == 0);
#ifdef XML3_REFERENCE_TEST
        xmlFreeDoc(doc);
#else
        xmlNodePtr borrowed;
        borrowed = xmlNewNode(xml_ns, BAD_CAST "borrowed");
        assert(borrowed != NULL && borrowed->ns == xml_ns);
        assert(xmlAddChild(root, borrowed) == borrowed);
        xmlUnlinkNode(borrowed);
        xmlFreeDoc(doc);
        assert(strcmp((const char *)borrowed->ns->href,
                      "http://www.w3.org/XML/1998/namespace") == 0);
        xmlFreeNode(borrowed);
#endif
    }
    {
        char version[] = "1.7";
        char name[] = "copied-name";
        char content[] = "copied-content";
        xmlDocPtr copied_doc = xmlNewDoc(BAD_CAST version);
        xmlNodePtr copied_node = xmlNewNode(NULL, BAD_CAST name);
        xmlNodePtr copied_text = xmlNewText(BAD_CAST content);
        xmlNodePtr null_text = xmlNewText(NULL);
        assert(copied_doc != NULL && copied_node != NULL &&
               copied_text != NULL && null_text != NULL);
        version[0] = '9';
        name[0] = 'x';
        content[0] = 'x';
        assert(strcmp((const char *)copied_doc->version, "1.7") == 0);
        assert(strcmp((const char *)copied_node->name, "copied-name") == 0);
        assert(strcmp((const char *)copied_text->content, "copied-content") == 0);
        assert(null_text->content == NULL);
        xmlFreeNode(copied_node);
        xmlFreeNode(copied_text);
        xmlFreeNode(null_text);
        xmlFreeDoc(copied_doc);
    }
}

static void test_promote_descendant_to_root(void) {
    static const char input[] = "<r><a><b/></a><tail/></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr old_root;
    xmlNodePtr promoted;
    xmlNodePtr tail;
    assert(doc != NULL);
    old_root = xmlDocGetRootElement(doc);
    promoted = old_root->children;
    assert(promoted != NULL);
    tail = promoted->next;
    assert(tail != NULL);
    assert(xmlDocSetRootElement(doc, promoted) == old_root);
    assert(doc->children == promoted && doc->last == promoted);
    assert(promoted->parent == (xmlNodePtr)doc && promoted->doc == doc);
    assert(promoted->prev == NULL && promoted->next == NULL);
    assert(old_root->parent == NULL && old_root->next == NULL);
    assert(old_root->children == tail && old_root->last == tail);
    assert(tail->parent == old_root && tail->prev == NULL);
    xmlFreeNode(old_root);
    assert(xmlDocGetRootElement(doc) == promoted);
    assert(promoted->children != NULL);
    assert(strcmp((const char *)promoted->children->name, "b") == 0);
    xmlFreeDoc(doc);
}

static void test_namespace_lookup_after_move(void) {
    static const char input[] =
        "<r><source xmlns:p='urn:move'><p:item a='v'><leaf/>"
        "<shadow xmlns:p='urn:other'><leaf/></shadow></p:item></source>"
        "<target/></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlNodePtr source;
    xmlNodePtr target;
    xmlNodePtr item;
    xmlNodePtr leaf;
    xmlNodePtr shadow;
    xmlNodePtr shadow_leaf;
    xmlNodePtr text;
    xmlNodePtr borrowed;
    xmlNodePtr borrowed_child;
    xmlAttrPtr attr;
    xmlNsPtr item_ns;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    source = root->children;
    target = source->next;
    item = source->children;
    leaf = item->children;
    shadow = leaf->next;
    shadow_leaf = shadow->children;
    attr = item->properties;
    item_ns = item->ns;
    assert(target != NULL && item != NULL && item_ns != NULL);
    assert(leaf != NULL && shadow != NULL && shadow_leaf != NULL && attr != NULL);

    assert(xmlAddChild(target, item) == item);
    assert(item->ns == item_ns);
    assert(xmlSearchNs(doc, item, BAD_CAST "p") == NULL);
    assert(xmlSearchNsByHref(doc, item, BAD_CAST "urn:move") == NULL);

    assert(xmlSearchNs(doc, leaf, BAD_CAST "p") == item_ns);
    assert(xmlSearchNsByHref(doc, leaf, BAD_CAST "urn:move") == item_ns);
    assert(xmlSearchNs(doc, (xmlNodePtr)attr, BAD_CAST "p") == item_ns);
    assert(xmlSearchNsByHref(doc, (xmlNodePtr)attr, BAD_CAST "urn:move") ==
           item_ns);

    text = xmlNewText(BAD_CAST "added");
    assert(text != NULL && xmlAddChild(item, text) == text);
    assert(xmlSearchNs(doc, text, BAD_CAST "p") == item_ns);
    assert(xmlSearchNsByHref(doc, text, BAD_CAST "urn:move") == item_ns);

    assert(shadow->nsDef != NULL);
    assert(xmlSearchNs(doc, shadow_leaf, BAD_CAST "p") == shadow->nsDef);
    assert(xmlSearchNsByHref(doc, shadow_leaf, BAD_CAST "urn:other") ==
           shadow->nsDef);
    assert(xmlSearchNsByHref(doc, shadow_leaf, BAD_CAST "urn:move") == NULL);

    borrowed = xmlNewNode(item_ns, BAD_CAST "borrowed");
    borrowed_child = xmlNewNode(NULL, BAD_CAST "child");
    assert(borrowed != NULL && borrowed_child != NULL);
    assert(xmlAddChild(target, borrowed) == borrowed);
    assert(xmlAddChild(borrowed, borrowed_child) == borrowed_child);
    assert(borrowed->ns == item_ns);
    assert(xmlSearchNs(doc, borrowed, BAD_CAST "p") == NULL);
    assert(xmlSearchNsByHref(doc, borrowed, BAD_CAST "urn:move") == NULL);
    assert(xmlSearchNs(doc, borrowed_child, BAD_CAST "p") == item_ns);
    assert(xmlSearchNsByHref(doc, borrowed_child, BAD_CAST "urn:move") ==
           item_ns);
    xmlFreeDoc(doc);
}

static void test_text_merge_and_edit_flow(void) {
    xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr left = xmlNewText(BAD_CAST "left");
    xmlNodePtr right = xmlNewText(BAD_CAST "right");
    assert(doc != NULL && root != NULL && left != NULL && right != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlAddChild(root, left) == left);
    assert(xmlAddChild(root, left) == left);
    assert(xmlAddChild(root, right) == left);
    assert(root->children == left && root->last == left);
    assert(left->parent == root && left->prev == NULL && left->next == NULL);
    assert_text(left, "leftright");
    xmlUnlinkNode(left);
    assert(root->children == NULL && root->last == NULL);
    assert(left->parent == NULL && left->prev == NULL && left->next == NULL);
    assert(left->doc == doc);
    xmlFreeNode(left);
    xmlFreeDoc(doc);
}

static void test_parsed_unlink_and_reinsert(void) {
    static const char input[] = "<r><a/><b/></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlNodePtr a;
    xmlNodePtr b;
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    a = root->children;
    b = a->next;
    xmlUnlinkNode(a);
    assert(root->children == b && root->last == b);
    assert(b->prev == NULL && a->parent == NULL && a->doc == doc);
    assert(xmlAddChild(root, a) == a);
    assert(root->last == a && a->prev == b && b->next == a);
    xmlFreeDoc(doc);
}

static void test_add_sibling_flow(void) {
    static const char input[] = "<r><a/><!--gap--><b/></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlDocPtr parsed;
    xmlNodePtr root, first, gap, last, added, left, right, after;
    xmlChar *bytes = NULL;
    int size = 0;
    assert(doc);
    root = xmlDocGetRootElement(doc);
    first = root->children;
    gap = first->next;
    last = root->last;
    added = xmlNewNode(NULL, BAD_CAST "added");
    assert(added && xmlAddSibling(first, added) == added);
    assert(first->next == gap && gap->next == last && last->next == added);
    assert(root->last == added && added->prev == last && added->doc == doc);
    assert(xmlAddSibling(first, added) == added);
    assert(xmlAddSibling(first, first) == NULL);
    assert(xmlAddSibling(first, last) == last);
    assert(gap->next == added && added->next == last && last->prev == added);
    assert(root->last == last && last->next == NULL);
    left = xmlNewText(BAD_CAST "left");
    right = xmlNewText(BAD_CAST "right");
    assert(left && right);
    assert(xmlAddSibling(first, left) == left);
    assert(xmlAddSibling(first, right) == left);
    assert(root->last == left && left->prev == last && last->next == left);
    assert_text(left, "leftright");
    after = xmlNewComment(BAD_CAST "after");
    assert(after && xmlAddSibling(root, after) == after);
    assert(doc->last == after && after->prev == root && root->next == after);
    xmlUnlinkNode(added);
    assert(xmlAddSibling(first, added) == added && root->last == added);
    xmlDocDumpMemoryEnc(doc, &bytes, &size, "UTF-8");
    assert(bytes && size > 0);
    parsed = xmlReadMemory((const char *)bytes, size, NULL, NULL, 0);
    assert(parsed && parsed->last->type == XML_COMMENT_NODE);
    assert_text(xmlDocGetRootElement(parsed), "leftright");
    assert(strcmp((const char *)xmlDocGetRootElement(parsed)->last->name, "added") == 0);
    xmlFreeDoc(parsed);
    xmlFree(bytes);
    xmlFreeDoc(doc);
}

static void test_adjacent_sibling_flow(void) {
    static const char input[] = "<r><a/><b/><c/></r>";
    xmlDocPtr doc =
        xmlReadMemory(input, (int)sizeof(input) - 1, NULL, NULL, 0);
    xmlDocPtr parsed;
    xmlNodePtr root;
    xmlNodePtr a;
    xmlNodePtr b;
    xmlNodePtr c;
    xmlNodePtr x;
    xmlNodePtr y;
    xmlNodePtr text;
    xmlNodePtr text2;
    xmlNodePtr cdata;
    xmlNodePtr comment;
    xmlNodePtr pi;
    xmlNodePtr prolog;
    xmlNodePtr epilog;
    xmlChar *bytes = NULL;
    int size = 0;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    a = root->children;
    b = a->next;
    c = root->last;
    x = xmlNewNode(NULL, BAD_CAST "x");
    y = xmlNewNode(NULL, BAD_CAST "y");
    assert(x && y);
    assert(xmlAddPrevSibling(c, x) == x);
    assert(b->next == x && x->next == c && c->prev == x);
    assert(xmlAddNextSibling(a, y) == y);
    assert(a->next == y && y->next == b && b->prev == y);
    assert(xmlAddPrevSibling(b, y) == y);
    assert(a->next == y && y->next == b);
    assert(xmlAddNextSibling(y, x) == x);
    assert(y->next == x && x->next == b);
    assert(xmlAddPrevSibling(a, c) == c);
    assert(root->children == c && c->next == a && a->prev == c);
    assert(xmlAddNextSibling(c, a) == a);
    assert(root->children == c && c->next == a);
    assert(xmlAddNextSibling(root->last, x) == x);
    assert(root->last == x && x->prev == b);
    assert(xmlAddPrevSibling(a, a) == NULL);

    prolog = xmlNewComment(BAD_CAST "before root");
    epilog = xmlNewPI(BAD_CAST "after", BAD_CAST "root");
    assert(prolog && epilog);
    assert(xmlAddPrevSibling(root, prolog) == prolog);
    assert(xmlAddNextSibling(root, epilog) == epilog);
    assert(doc->children == prolog && prolog->next == root);
    assert(root->next == epilog && doc->last == epilog);
    assert(xmlAddNextSibling(epilog, root) == root);
    assert(doc->last == root && epilog->next == root);
    assert(xmlAddPrevSibling(epilog, root) == root);
    assert(prolog->next == root && root->next == epilog && doc->last == epilog);

    text = xmlNewText(BAD_CAST "left");
    cdata = xmlNewCDataBlock(doc, BAD_CAST "middle", 6);
    comment = xmlNewComment(BAD_CAST "mark");
    pi = xmlNewPI(BAD_CAST "p", BAD_CAST "value");
    text2 = xmlNewText(BAD_CAST "second");
    assert(text && text2 && cdata && comment && pi);
    assert(xmlAddNextSibling(c, text) == text);
    assert(xmlAddNextSibling(text, text2) == text2);
    assert(xmlAddNextSibling(text2, cdata) == cdata);
    assert(xmlAddNextSibling(cdata, comment) == comment);
    assert(xmlAddNextSibling(comment, pi) == pi);
    assert(text->next == text2 && text2->next == cdata);
    assert(cdata->next == comment);
    assert(comment->next == pi && pi->prev == comment);
    assert(text->next != text);
    {
        xmlAttrPtr attr = xmlNewProp(root, BAD_CAST "value", BAD_CAST "old");
        xmlNodePtr value_tail = xmlNewText(BAD_CAST "tail");
        assert(attr && value_tail && attr->children);
        assert(xmlAddNextSibling(attr->children, value_tail) == value_tail);
        assert(attr->children->next == value_tail);
        assert(attr->children != value_tail);
    }
    xmlDocDumpMemoryEnc(doc, &bytes, &size, "UTF-8");
    assert(bytes && size > 0);
    parsed = xmlReadMemory((const char *)bytes, size, NULL, NULL, 0);
    assert(parsed != NULL);
    assert_text(xmlDocGetRootElement(parsed), "leftsecondmiddle");
    assert(parsed->children->type == XML_COMMENT_NODE);
    assert(parsed->last->type == XML_PI_NODE);
    {
        xmlNodePtr element = xmlDocGetRootElement(parsed)->children;
        while (element && element->type != XML_ELEMENT_NODE)
            element = element->next;
        assert(element && strcmp((const char *)element->name, "c") == 0);
        do {
            element = element->next;
        } while (element && element->type != XML_ELEMENT_NODE);
        assert(element && strcmp((const char *)element->name, "a") == 0);
    }
    xmlFreeDoc(parsed);
    xmlFree(bytes);
    xmlFreeDoc(doc);
}

#ifndef XML3_REFERENCE_TEST
static void test_sibling_rejections_and_lifetime(void) {
    static const char input[] = "<r><a/><b/></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlDocPtr other = xmlReadMemory("<other><foreign/></other>", 25, NULL, NULL, 0);
    xmlNodePtr root, first, last, foreign, detached, text;
    xmlAttrPtr attr;
    xmlNode unmanaged = {0};
    assert(doc && other);
    root = xmlDocGetRootElement(doc);
    first = root->children;
    last = root->last;
    foreign = xmlDocGetRootElement(other)->children;
    detached = xmlNewNode(NULL, BAD_CAST "detached");
    text = xmlNewText(BAD_CAST "keep");
    attr = xmlNewProp(root, BAD_CAST "a", BAD_CAST "value");
    assert(detached && text && attr);
    assert(xmlAddSibling(NULL, detached) == NULL);
    assert(xmlAddSibling(first, NULL) == NULL);
    assert(xmlAddSibling(&unmanaged, detached) == NULL);
    assert(xmlAddSibling(first, &unmanaged) == NULL);
    assert(xmlAddSibling(detached, text) == NULL);
    assert(xmlAddSibling(first, (xmlNodePtr)attr) == NULL);
    assert(xmlAddSibling((xmlNodePtr)attr, detached) == NULL);
    assert(xmlAddSibling(root, detached) == NULL);
    assert(xmlAddSibling(root, text) == NULL);
    assert(xmlAddSibling(first, root) == NULL);
    assert(xmlAddSibling(first, foreign) == NULL);
    assert(xmlAddPrevSibling(NULL, detached) == NULL);
    assert(xmlAddNextSibling(first, NULL) == NULL);
    assert(xmlAddPrevSibling(&unmanaged, detached) == NULL);
    assert(xmlAddNextSibling(first, &unmanaged) == NULL);
    assert(xmlAddPrevSibling(root, (xmlNodePtr)doc) == NULL);
    assert(xmlAddNextSibling((xmlNodePtr)doc, detached) == NULL);
    assert(xmlAddPrevSibling(detached, text) == NULL);
    assert(xmlAddNextSibling(first, first) == NULL);
    assert(xmlAddPrevSibling(first, root) == NULL);
    assert(xmlAddPrevSibling(first, (xmlNodePtr)attr) == NULL);
    assert(xmlAddNextSibling((xmlNodePtr)attr, detached) == NULL);
    assert(xmlAddPrevSibling(root, detached) == NULL);
    assert(xmlAddNextSibling(first, root) == NULL);
    assert(xmlAddNextSibling(first, foreign) == NULL);
    assert(foreign->parent == xmlDocGetRootElement(other) && foreign->doc == other);
    assert(root->properties == attr && attr->parent == root);
    assert(root->children == first && first->next == last && root->last == last);
    assert(root->parent == (xmlNodePtr)doc && doc->children == root);
    assert(detached->parent == NULL && detached->doc == NULL);
    assert(text->parent == NULL && text->doc == NULL);
    xmlFreeNode(text);
    xmlFreeDoc(other);
    xmlUnlinkNode(root);
    xmlFreeDoc(doc);
    assert(xmlAddSibling(first, detached) == detached && root->last == detached);
    assert(last->next == detached && detached->prev == last);
    assert(detached->parent == root && detached->doc == first->doc);
    xmlFreeNode(root);
    xmlResetLastError();
}

static void test_cross_document_detached_lifetime(void) {
    static const char input[] =
        "<r><before/><sub xmlns:p='urn:retained'><p:leaf>retained</p:leaf></sub><after/></r>";
    static const char second_input[] = "<target/>";
    xmlDocPtr first = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlDocPtr second = xmlReadMemory(second_input,
                                    (int)strlen(second_input), NULL, NULL, 0);
    xmlNodePtr first_root;
    xmlNodePtr before;
    xmlNodePtr subtree;
    xmlNodePtr leaf;
    xmlNodePtr after;
    xmlNodePtr inserted;
    xmlDocPtr parsed;
    xmlNsPtr ns;
    xmlAttrPtr literal_attr;
    xmlAttrPtr duplicate_attr;
    xmlAttrPtr null_attr;
    xmlAttrPtr empty_attr;
    xmlChar *value;
    xmlChar *bytes = NULL;
    int size = 0;
    char literal[] = "original&amp;<";
    xmlDocPtr fresh;

    assert(first != NULL && second != NULL);
    first_root = xmlDocGetRootElement(first);
    before = first_root->children;
    subtree = before->next;
    leaf = subtree->children;
    after = subtree->next;
    assert(before->next == subtree && subtree->next == after);
    assert(subtree->parent == first_root && subtree->doc == first);
    assert(subtree->prev == before);
    assert(leaf->parent == subtree && leaf->doc == first);
    ns = xmlSearchNs(first, subtree, BAD_CAST "p");
    assert(ns != NULL && subtree->nsDef == ns);
    assert(xmlAddNextSibling(after, subtree) == subtree);
    assert(before->next == after && after->next == subtree);
    assert(first_root->last == subtree && subtree->prev == after);
    xmlDocDumpMemoryEnc(first, &bytes, &size, "UTF-8");
    assert(bytes != NULL && size > 0);
    parsed = xmlReadMemory((const char *)bytes, size, NULL, NULL, 0);
    assert(parsed != NULL);
    {
        xmlNodePtr serialized_last = xmlDocGetRootElement(parsed)->last;
        assert(serialized_last != NULL &&
               strcmp((const char *)serialized_last->name, "sub") == 0);
        assert(serialized_last->prev != NULL &&
               strcmp((const char *)serialized_last->prev->name, "after") == 0);
    }
    xmlFreeDoc(parsed);
    xmlFree(bytes);
    bytes = NULL;

    literal_attr = xmlNewProp(subtree, BAD_CAST "duplicate", BAD_CAST literal);
    duplicate_attr = xmlNewProp(subtree, BAD_CAST "duplicate", BAD_CAST "second");
    null_attr = xmlNewProp(subtree, BAD_CAST "null-value", NULL);
    empty_attr = xmlNewProp(subtree, BAD_CAST "empty-value", BAD_CAST "");
    assert(literal_attr != NULL && duplicate_attr != NULL);
    assert(null_attr != NULL && empty_attr != NULL);
    literal[0] = 'X';
    assert(subtree->properties == literal_attr);
    assert(literal_attr->next == duplicate_attr &&
           duplicate_attr->prev == literal_attr);
    assert(duplicate_attr->next == null_attr &&
           null_attr->prev == duplicate_attr);
    assert(null_attr->next == empty_attr && empty_attr->prev == null_attr);
    assert(null_attr->children == NULL && null_attr->last == NULL);
    assert(empty_attr->children != NULL && empty_attr->last == empty_attr->children);
    assert(empty_attr->children->type == XML_TEXT_NODE);
    assert(empty_attr->children->content != NULL &&
           empty_attr->children->content[0] == 0);
    value = xmlGetProp(subtree, BAD_CAST "duplicate");
    assert(value != NULL && strcmp((const char *)value, "original&amp;<") == 0);
    xmlFree(value);

    xmlUnlinkNode(subtree);
    assert(first_root->children == before && before->next == after);
    assert(first_root->last == after && after->next == NULL);
    assert(subtree->parent == NULL && subtree->prev == NULL && subtree->next == NULL);
    assert(subtree->doc == first);
    xmlFreeDoc(first);

    assert(subtree->parent == NULL && subtree->children == leaf);
    assert(subtree->properties == literal_attr && literal_attr->next == duplicate_attr);
    assert(xmlSearchNs(NULL, subtree, BAD_CAST "p") == ns);
    inserted = xmlNewComment(BAD_CAST "retained sibling");
    assert(inserted != NULL);
    assert(xmlAddNextSibling(leaf, inserted) == inserted);
    assert(leaf->next == inserted && inserted->prev == leaf);
    value = xmlNodeGetContent(subtree);
    assert(value != NULL && strcmp((const char *)value, "retained") == 0);
    xmlFree(value);
    value = xmlGetProp(subtree, BAD_CAST "duplicate");
    assert(value != NULL && strcmp((const char *)value, "original&amp;<") == 0);
    xmlFree(value);
    assert(xmlSetProp(subtree, BAD_CAST "duplicate", BAD_CAST "updated") ==
           literal_attr);
    value = xmlGetProp(subtree, BAD_CAST "duplicate");
    assert(value != NULL && strcmp((const char *)value, "updated") == 0);
    xmlFree(value);
    value = xmlGetProp(subtree, BAD_CAST "null-value");
    assert(value != NULL && value[0] == 0);
    xmlFree(value);
    value = xmlGetProp(subtree, BAD_CAST "empty-value");
    assert(value != NULL && value[0] == 0);
    xmlFree(value);

    xmlFreeNode(subtree);
    xmlFreeDoc(second);

    fresh = xmlNewDoc(NULL);
    assert(fresh != NULL);
    xmlFreeDoc(fresh);
}

static void test_adjacent_sibling_document_and_namespace_pins(void) {
    static const char input[] =
        "<r><sub xmlns:p='urn:retained'><p:leaf>retained</p:leaf></sub>"
        "<target/></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)sizeof(input) - 1, NULL, NULL, 0);
    xmlNodePtr root;
    xmlNodePtr subtree;
    xmlNodePtr target;
    xmlNodePtr leaf;
    xmlNodePtr inserted;
    xmlNsPtr ns;
    xmlChar *content;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    subtree = root->children;
    target = subtree->next;
    leaf = subtree->children;
    ns = xmlSearchNs(doc, subtree, BAD_CAST "p");
    assert(ns != NULL);
    assert(xmlAddNextSibling(target, subtree) == subtree);
    assert(root->children == target && target->next == subtree);
    xmlUnlinkNode(root);
    xmlFreeDoc(doc);

    inserted = xmlNewText(BAD_CAST "inserted");
    assert(inserted != NULL);
    assert(xmlAddNextSibling(leaf, inserted) == inserted);
    assert(leaf->next == inserted && inserted->parent == subtree);
    assert(xmlSearchNs(NULL, subtree, BAD_CAST "p") == ns);
    content = xmlNodeGetContent(subtree);
    assert(content != NULL && strcmp((const char *)content, "retainedinserted") == 0);
    xmlFree(content);
    xmlFreeNode(root);
}
#endif

#ifndef XML3_REFERENCE_TEST
static void test_sticky_mutator_errors(void) {
    xmlDocPtr doc;
    xmlNodePtr root;
    xmlNodePtr text;
    xmlNodePtr survivor;
    int code;
    assert(xmlReadMemory("<broken>", 8, NULL, NULL, 0) == NULL);
    assert(xmlGetLastError() != NULL);
    code = xmlGetLastError()->code;
    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "root");
    text = xmlNewText(BAD_CAST "x");
    assert(doc != NULL && root != NULL && text != NULL);
    assert(xmlGetLastError()->code == code);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlGetLastError()->code == code);
    assert(xmlAddChild(root, text) == text);
    assert(xmlGetLastError()->code == code);
    survivor = xmlNewText(BAD_CAST "y");
    assert(survivor != NULL);
    assert(xmlGetLastError()->code == code);
    assert(xmlAddChild(root, survivor) == text);
    assert(xmlGetLastError()->code == code);
    xmlUnlinkNode(text);
    assert(xmlGetLastError()->code == code);
    xmlFreeNode(text);
    xmlFreeDoc(doc);
    assert(xmlGetLastError()->code == code);
    xmlResetLastError();
}

static void test_safe_ownership(void) {
    static const char input[] =
        "<root xmlns:p='urn:test'><p:item a='value'><child/></p:item></root>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlNodePtr item;
    xmlNsPtr inherited;
    xmlChar *value;
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    item = root->children;
    inherited = item->ns;
    assert(inherited != NULL);
    xmlUnlinkNode(item);
    xmlFreeDoc(doc);
    assert(strcmp((const char *)inherited->href, "urn:test") == 0);
    value = xmlGetProp(item, BAD_CAST "a");
    assert(value != NULL && strcmp((const char *)value, "value") == 0);
    xmlFree(value);
    xmlFreeNode(item);

    doc = xmlReadMemory("<r xmlns:p='urn:keep'/>", 23, NULL, NULL, 0);
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    inherited = xmlSearchNs(doc, root, BAD_CAST "p");
    item = xmlNewNode(inherited, BAD_CAST "borrowed");
    assert(item != NULL);
    xmlFreeDoc(doc);
    assert(strcmp((const char *)item->ns->href, "urn:keep") == 0);
    xmlFreeNode(item);

    {
        xmlDocPtr first = xmlNewDoc(NULL);
        xmlDocPtr second = xmlNewDoc(NULL);
        xmlNodePtr parent = xmlNewNode(NULL, BAD_CAST "parent");
        xmlNodePtr child = xmlNewNode(NULL, BAD_CAST "child");
        xmlNodePtr foreign = xmlNewNode(NULL, BAD_CAST "foreign");
        assert(first != NULL && second != NULL && parent != NULL);
        assert(child != NULL && foreign != NULL);
        xmlDocSetRootElement(first, parent);
        xmlDocSetRootElement(second, foreign);
        assert(xmlAddChild(parent, child) == child);
        assert(xmlAddChild(child, parent) == NULL);
        assert(parent->children == child && child->parent == parent);
        assert(xmlAddChild(parent, foreign) == NULL);
        assert(foreign->parent == (xmlNodePtr)second);
        xmlFreeNode(child);
        assert(parent->children == NULL && parent->last == NULL);
        xmlFreeDoc(first);
        xmlFreeDoc(second);
    }

    {
        enum { DEPTH = 12000 };
        xmlNodePtr top = xmlNewNode(NULL, BAD_CAST "n");
        xmlNodePtr current = top;
        int i;
        assert(top != NULL);
        for (i = 1; i < DEPTH; ++i) {
            xmlNodePtr next = xmlNewNode(NULL, BAD_CAST "n");
            assert(next != NULL);
            assert(xmlAddChild(current, next) == next);
            current = next;
        }
        xmlFreeNode(top);
    }
}

static void test_free_rejects_unsupported_types(void) {
    static const char input[] =
        "<r xmlns:p='urn:free' a='value'><p:item>child</p:item></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlNsPtr ns;
    xmlAttrPtr attr;
    xmlChar *value;
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    ns = root->nsDef;
    attr = root->properties;
    assert(ns != NULL && attr != NULL);

    xmlFreeNode((xmlNodePtr)ns);
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->domain == XML_FROM_TREE);
    assert(xmlGetLastError()->code == 115);
    assert(root->nsDef == ns && root->properties == attr);
    assert(strcmp((const char *)root->name, "r") == 0);
    assert(strcmp((const char *)ns->prefix, "p") == 0);
    assert(strcmp((const char *)ns->href, "urn:free") == 0);
    assert_text(root, "child");

    xmlResetLastError();
    xmlFreeNode((xmlNodePtr)attr);
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->domain == XML_FROM_TREE);
    assert(xmlGetLastError()->code == 115);
    assert(root->properties == attr && attr->parent == root);
    assert(strcmp((const char *)attr->name, "a") == 0);
    value = xmlGetProp(root, BAD_CAST "a");
    assert(value != NULL && strcmp((const char *)value, "value") == 0);
    xmlFree(value);
    assert_text(root, "child");
    xmlResetLastError();
    xmlFreeDoc(doc);
}
#endif

static void test_free_node_list(void) {
    static const char input[] =
        "<r><keep/><remove a='1'><nested/></remove>text<!--tail--></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root, keep, fresh, standalone;
    xmlChar *bytes = NULL;
    int length = 0;
    xmlDocPtr reparsed;
    assert(doc);
    root = xmlDocGetRootElement(doc);
    keep = root->children;
    xmlFreeNodeList(NULL);
    xmlFreeNodeList(keep->next);
#ifdef XML3_REFERENCE_TEST
    /* libxml2 requires callers to repair the surviving list links. */
    keep->next = NULL;
    root->last = keep;
#endif
    assert(root->children == keep && root->last == keep && keep->next == NULL);
    assert(keep->parent == root && keep->prev == NULL);
    fresh = xmlNewTextChild(root, NULL, BAD_CAST "fresh", BAD_CAST "new & data");
    assert(fresh && keep->next == fresh && fresh->prev == keep);
    xmlDocDumpMemoryEnc(doc, &bytes, &length, "UTF-8");
    assert(bytes && length > 0);
    reparsed = xmlReadMemory((const char *)bytes, length, NULL, NULL, 0);
    assert(reparsed && xmlChildElementCount(xmlDocGetRootElement(reparsed)) == 2);
    assert_text(xmlDocGetRootElement(reparsed)->last, "new & data");
    xmlFreeDoc(reparsed);
    xmlFree(bytes);
    xmlFreeNodeList(root->children);
#ifdef XML3_REFERENCE_TEST
    root->children = root->last = NULL;
#endif
    assert(root->children == NULL && root->last == NULL);
    assert(xmlNewChild(root, NULL, BAD_CAST "again", NULL));
    fresh = xmlNewComment(BAD_CAST "document tail");
    assert(fresh && xmlAddChild((xmlNodePtr)doc, fresh) == fresh);
    xmlFreeNodeList(doc->children);
#ifdef XML3_REFERENCE_TEST
    doc->children = doc->last = NULL;
#endif
    assert(doc->children == NULL && doc->last == NULL);
    assert(xmlDocGetRootElement(doc) == NULL);
    xmlFreeDoc(doc);
    standalone = xmlNewNode(NULL, BAD_CAST "standalone");
    assert(standalone && xmlNewChild(standalone, NULL, BAD_CAST "child", NULL));
    xmlFreeNodeList(standalone);
}

#ifndef XML3_REFERENCE_TEST
static void test_release_list_lifetime_and_rejections(void) {
    static const char input[] = "<r a='one' b='two'><keep/><donor/></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root, keep, donor;
    xmlNsPtr ns;
    xmlAttrPtr first;
    xmlNode unmanaged = {0};
    assert(doc);
    root = xmlDocGetRootElement(doc);
    keep = root->children;
    donor = keep->next;
    first = root->properties;
    ns = xmlNewNs(donor, BAD_CAST "urn:retained", BAD_CAST "p");
    assert(ns);
    xmlSetNs(keep, ns);
    assert(xmlNewChild(root, ns, BAD_CAST "borrower", NULL));
    assert(xmlNewNsProp(root, ns, BAD_CAST "borrowed", BAD_CAST "v"));
    xmlResetLastError();
    xmlFreeNodeList((xmlNodePtr)doc);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    xmlResetLastError();
    xmlFreeNodeList((xmlNodePtr)first);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    xmlResetLastError();
    xmlFreeNodeList((xmlNodePtr)ns);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    xmlResetLastError();
    xmlFreePropList((xmlAttrPtr)root);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    xmlResetLastError();
    xmlFreePropList((xmlAttrPtr)ns);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    unmanaged.type = XML_ELEMENT_NODE;
    unmanaged.next = &unmanaged;
    xmlResetLastError();
    xmlFreeNodeList(&unmanaged);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    xmlResetLastError();
    xmlFreePropList((xmlAttrPtr)&unmanaged);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    xmlFreeNodeList(NULL);
    xmlFreePropList(NULL);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    assert(root->children == keep && keep->next == donor && root->properties == first);
    xmlResetLastError();
    xmlUnlinkNode(root);
    xmlFreeDoc(doc);
    xmlFreeNodeList(donor);
    assert(root->children == keep && root->last == keep && keep->next == NULL);
    assert(keep->ns == ns && strcmp((const char *)ns->href, "urn:retained") == 0);
    xmlFreePropList(root->properties);
    assert(root->properties == NULL && keep->ns == ns);
    assert(strcmp((const char *)ns->prefix, "p") == 0);
    xmlSetNs(keep, NULL);
    assert(keep->ns == NULL);
    xmlFreeNodeList(root->children);
    assert(root->children == NULL && root->last == NULL);
    assert(xmlNewChild(root, NULL, BAD_CAST "after", NULL));
    xmlFreeNode(root);
}
#endif

int main(void) {
    test_free_node_list();
    test_constructors_and_root_replacement();
    test_promote_descendant_to_root();
    test_namespace_lookup_after_move();
    test_text_merge_and_edit_flow();
    test_parsed_unlink_and_reinsert();
    test_add_sibling_flow();
    test_adjacent_sibling_flow();
#ifndef XML3_REFERENCE_TEST
    test_sibling_rejections_and_lifetime();
    test_release_list_lifetime_and_rejections();
    test_cross_document_detached_lifetime();
    test_adjacent_sibling_document_and_namespace_pins();
    test_sticky_mutator_errors();
    test_safe_ownership();
    test_free_rejects_unsupported_types();
#endif
    puts("DOM ownership and editing tests passed");
    return 0;
}
