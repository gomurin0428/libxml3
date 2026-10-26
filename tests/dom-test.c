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

#ifndef XML3_REFERENCE_TEST
static void test_cross_document_detached_lifetime(void) {
    static const char input[] =
        "<r><sub xmlns:p='urn:retained'><p:leaf>retained</p:leaf></sub></r>";
    static const char second_input[] = "<target/>";
    xmlDocPtr first = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlDocPtr second = xmlReadMemory(second_input,
                                    (int)strlen(second_input), NULL, NULL, 0);
    xmlNodePtr first_root;
    xmlNodePtr subtree;
    xmlNodePtr leaf;
    xmlNsPtr ns;
    xmlAttrPtr literal_attr;
    xmlAttrPtr duplicate_attr;
    xmlAttrPtr null_attr;
    xmlAttrPtr empty_attr;
    xmlChar *value;
    char literal[] = "original&amp;<";
    xmlDocPtr fresh;

    assert(first != NULL && second != NULL);
    first_root = xmlDocGetRootElement(first);
    subtree = first_root->children;
    leaf = subtree->children;
    assert(first_root->children == subtree && first_root->last == subtree);
    assert(subtree->parent == first_root && subtree->doc == first);
    assert(subtree->prev == NULL && subtree->next == NULL);
    assert(leaf->parent == subtree && leaf->doc == first);
    ns = xmlSearchNs(first, subtree, BAD_CAST "p");
    assert(ns != NULL && subtree->nsDef == ns);

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
    assert(first_root->children == NULL && first_root->last == NULL);
    assert(subtree->parent == NULL && subtree->prev == NULL && subtree->next == NULL);
    assert(subtree->doc == first);
    xmlFreeDoc(first);

    assert(subtree->parent == NULL && subtree->children == leaf);
    assert(subtree->properties == literal_attr && literal_attr->next == duplicate_attr);
    assert(xmlSearchNs(NULL, subtree, BAD_CAST "p") == ns);
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

int main(void) {
    test_constructors_and_root_replacement();
    test_promote_descendant_to_root();
    test_namespace_lookup_after_move();
    test_text_merge_and_edit_flow();
    test_parsed_unlink_and_reinsert();
#ifndef XML3_REFERENCE_TEST
    test_cross_document_detached_lifetime();
    test_sticky_mutator_errors();
    test_safe_ownership();
    test_free_rejects_unsupported_types();
#endif
    puts("DOM ownership and editing tests passed");
    return 0;
}
