#include <libxml/parser.h>
#include <libxml/tree.h>
#ifdef XML3_REFERENCE_TEST
#include <libxml/xmlversion.h>
#endif

#include <assert.h>
#include <stdio.h>
#include <string.h>

#ifdef XML3_REFERENCE_TEST
static void check_reference_version(void) {
    assert(LIBXML_VERSION == 21504);
    assert(xmlParserVersion != NULL);
    assert(strcmp(xmlParserVersion, XML3_REFERENCE_VERSION_STRING) == 0);
}
#else
static void check_reference_version(void) {}
#endif

static void assert_value(xmlAttrPtr attr, const char *value) {
    xmlChar *content;
    assert(attr != NULL && attr->type == XML_ATTRIBUTE_NODE);
    content = xmlNodeGetContent((xmlNodePtr)attr);
    assert(content != NULL && strcmp((const char *)content, value) == 0);
    xmlFree(content);
    if (attr->children != NULL) {
        assert(attr->children == attr->last);
        assert(attr->children->type == XML_TEXT_NODE);
        assert(attr->children->parent == (xmlNodePtr)attr);
        assert(attr->children->doc == attr->doc);
        assert(attr->children->next == NULL && attr->children->prev == NULL);
    }
}

static void test_edit_flow(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlAttrPtr first, duplicate, last, created;
    char name[] = "mode";
    char value[] = "raw &amp; &#65; &missing; < > \" '\t\n";
    assert(doc != NULL && root != NULL);
    first = xmlNewProp(root, BAD_CAST name, BAD_CAST value);
    assert(first != NULL && first->doc == NULL && first->parent == root);
    name[0] = 'X';
    value[0] = 'X';
    assert(strcmp((const char *)first->name, "mode") == 0);
    assert_value(first, "raw &amp; &#65; &missing; < > \" '\t\n");
    duplicate = xmlNewProp(root, BAD_CAST "mode", BAD_CAST "duplicate");
    last = xmlNewProp(root, BAD_CAST "last", NULL);
    assert(duplicate != NULL && last != NULL);
    assert(root->properties == first && first->prev == NULL);
    assert(first->next == duplicate && duplicate->prev == first);
    assert(duplicate->next == last && last->prev == duplicate);
    assert(last->next == NULL && last->children == NULL && last->last == NULL);
    assert_value(last, "");

    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(first->doc == doc && duplicate->doc == doc && last->doc == doc);
    assert_value(first, "raw &amp; &#65; &missing; < > \" '\t\n");
    first->_private = &name;
    assert(xmlSetProp(root, BAD_CAST "mode", BAD_CAST "updated") == first);
    assert(first->_private == &name && first->next == duplicate);
    assert_value(first, "updated");
    assert_value(duplicate, "duplicate");
    assert(xmlSetProp(root, BAD_CAST "mode", first->children->content + 2) == first);
    assert_value(first, "dated");
    assert(xmlSetProp(root, BAD_CAST "mode", NULL) == first);
    assert(first->children == NULL && first->last == NULL);
    assert_value(first, "");
    assert(xmlSetProp(root, BAD_CAST "mode", BAD_CAST "") == first);
    assert(first->children != NULL);
    assert_value(first, "");
    created = xmlSetProp(root, BAD_CAST "added", BAD_CAST "値 &amp;");
    assert(created != NULL && last->next == created && created->prev == last);
    assert_value(created, "値 &amp;");

    assert(xmlRemoveProp(duplicate) == 0);
    assert(first->next == last && last->prev == first);
    assert(xmlUnsetProp(root, BAD_CAST "mode") == 0);
    assert(root->properties == last && last->prev == NULL);
    assert(xmlUnsetProp(root, BAD_CAST "absent") == -1);
    assert(xmlRemoveProp(created) == 0 && last->next == NULL);
    assert(xmlRemoveProp(last) == 0 && root->properties == NULL);
    xmlFreeDoc(doc);
}

static void test_parsed_attributes(void) {
    static const char input[] =
        "<root xmlns:p='urn:attrs' p:a='namespaced' a='old &amp; value' b='b'/>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlAttrPtr namespaced, plain;
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    namespaced = root->properties;
    plain = namespaced->next;
    assert(namespaced->ns != NULL && plain->ns == NULL);
    assert_value(plain, "old & value");
    assert(xmlSetProp(root, BAD_CAST "a", BAD_CAST "&amp; &#65;") == plain);
    assert_value(plain, "&amp; &#65;");
    assert_value(namespaced, "namespaced");
    assert(xmlUnsetProp(root, BAD_CAST "a") == 0);
    assert(root->properties == namespaced && namespaced->next->prev == namespaced);
    assert(xmlUnsetProp(root, BAD_CAST "a") == -1);
    plain = xmlSetProp(root, BAD_CAST "a", BAD_CAST "new");
    assert(plain != NULL && plain->ns == NULL && plain->doc == doc);
    assert_value(namespaced, "namespaced");
    xmlFreeDoc(doc);
}

static void test_standalone_attributes(void) {
    xmlAttrPtr attr = xmlNewProp(NULL, BAD_CAST "standalone", BAD_CAST "value");
    assert(attr != NULL && attr->parent == NULL && attr->doc == NULL);
    assert_value(attr, "value");
    assert(xmlRemoveProp(attr) == -1);
    assert_value(attr, "value");
    xmlFreeProp(attr);
    xmlFreeProp(NULL);
    xmlResetLastError();
}

static void assert_round_trip(xmlDocPtr doc, const char *name,
                              const char *uri, const char *value) {
    xmlChar *bytes = NULL;
    int size = 0;
    xmlDocPtr parsed;
    xmlDocDumpMemoryEnc(doc, &bytes, &size, "UTF-8");
    assert(bytes && size > 0);
    parsed = xmlReadMemory((const char *)bytes, size, NULL, NULL, 0);
    assert(parsed);
    assert_value(xmlHasNsProp(xmlDocGetRootElement(parsed), BAD_CAST name,
                             BAD_CAST uri), value);
    xmlFreeDoc(parsed);
    xmlFree(bytes);
}

static void test_attach_attributes(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr other;
    xmlAttrPtr first, old, last, replacement, source, empty;
    assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
    other = xmlNewChild(root, NULL, BAD_CAST "other", NULL);
    first = xmlNewProp(root, BAD_CAST "first", BAD_CAST "keep");
    old = xmlNewProp(root, BAD_CAST "a", BAD_CAST "old");
    last = xmlNewProp(root, BAD_CAST "last", BAD_CAST "last");
    replacement = xmlNewDocProp(doc, BAD_CAST "a", BAD_CAST "new&amp;value");
    assert(other && first && old && last && replacement);
    assert(xmlAddChild(root, (xmlNodePtr)replacement) == (xmlNodePtr)replacement);
    assert(root->children == other && root->last == other);
    assert(root->properties == first && first->next == last && last->prev == first);
    assert(last->next == replacement && replacement->prev == last);
    assert(replacement->next == NULL && replacement->parent == root);
    assert_value(replacement, "new&value");
    assert_round_trip(doc, "a", NULL, "new&value");

    assert(xmlAddChild(root, (xmlNodePtr)replacement) == (xmlNodePtr)replacement);
    assert(replacement->prev == last && replacement->next == NULL);
    assert(xmlAddChild(root, (xmlNodePtr)first) == (xmlNodePtr)first);
    assert(root->properties == last && last->prev == NULL);
    assert(last->next == replacement && replacement->next == first);
    assert(first->prev == replacement && first->next == NULL);

    source = xmlNewProp(other, BAD_CAST "a", BAD_CAST "moved");
    assert(source);
    assert(xmlAddChild(root, (xmlNodePtr)source) == (xmlNodePtr)source);
    assert(other->properties == NULL);
    assert(last->next == first && first->prev == last);
    assert(first->next == source && source->prev == first && source->next == NULL);
    assert(source->doc == doc && source->parent == root);
    assert_value(source, "moved");
    empty = xmlNewDocProp(NULL, BAD_CAST "empty", NULL);
    assert(empty && xmlAddChild(other, (xmlNodePtr)empty) == (xmlNodePtr)empty);
    assert(empty->doc == doc && empty->parent == other && empty->children == NULL);
    assert_round_trip(doc, "a", NULL, "moved");
    xmlFreeDoc(doc);
}

static void test_attach_namespace_attributes(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNsPtr p, q, z;
    xmlAttrPtr plain, old, different, replacement;
    assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
    p = xmlNewNs(root, BAD_CAST "urn:same", BAD_CAST "p");
    q = xmlNewNs(root, BAD_CAST "urn:same", BAD_CAST "q");
    z = xmlNewNs(root, BAD_CAST "urn:other", BAD_CAST "z");
    assert(p && q && z);
    plain = xmlNewProp(root, BAD_CAST "id", BAD_CAST "plain");
    old = xmlNewNsProp(root, p, BAD_CAST "id", BAD_CAST "old");
    different = xmlNewNsProp(root, z, BAD_CAST "id", BAD_CAST "other");
    replacement = xmlNewNsProp(NULL, q, BAD_CAST "id", BAD_CAST "new");
    assert(plain && old && different && replacement);
    assert(xmlAddChild(root, (xmlNodePtr)replacement) == (xmlNodePtr)replacement);
    assert(root->properties == plain && plain->next == different);
    assert(different->prev == plain && different->next == replacement);
    assert(replacement->prev == different && replacement->next == NULL);
    assert(replacement->ns == q && replacement->doc == doc);
    assert(xmlHasNsProp(root, BAD_CAST "id", BAD_CAST "urn:same") == replacement);
    assert(xmlHasNsProp(root, BAD_CAST "id", NULL) == plain);
    assert_value(different, "other");
    assert_round_trip(doc, "id", "urn:same", "new");
    xmlFreeDoc(doc);
}

static void test_add_attribute_sibling(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNsPtr p, q;
    xmlAttrPtr plain, old, incoming;
    assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
    p = xmlNewNs(root, BAD_CAST "urn:same", BAD_CAST "p");
    q = xmlNewNs(root, BAD_CAST "urn:same", BAD_CAST "q");
    assert(p && q);
    plain = xmlNewProp(root, BAD_CAST "id", BAD_CAST "plain");
    old = xmlNewNsProp(root, p, BAD_CAST "id", BAD_CAST "old");
    incoming = xmlNewNsProp(NULL, q, BAD_CAST "id", BAD_CAST "new");
    assert(plain && old && incoming);
    assert(xmlAddSibling((xmlNodePtr)plain, (xmlNodePtr)incoming) == (xmlNodePtr)incoming);
    assert(root->properties == plain && plain->next == incoming && incoming->prev == plain);
    assert(incoming->parent == root && incoming->next == NULL && incoming->ns == q);
    assert(xmlAddSibling((xmlNodePtr)plain, (xmlNodePtr)incoming) == (xmlNodePtr)incoming);
    assert(xmlAddSibling((xmlNodePtr)incoming, (xmlNodePtr)incoming) == NULL);
    assert_value(plain, "plain");
    assert_round_trip(doc, "id", "urn:same", "new");
    xmlFreeDoc(doc);
}

static void test_unlink_attributes(void) {
    static const char input[] =
        "<root xmlns:p='urn:attrs' first='1' p:middle='2' last='3'><target/></root>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root, target;
    xmlAttrPtr first, middle, last;
    int marker = 0;
    assert(doc);
    root = xmlDocGetRootElement(doc);
    target = root->children;
    first = root->properties;
    middle = first->next;
    last = middle->next;
    middle->_private = &marker;
    xmlUnlinkNode((xmlNodePtr)middle);
    assert(root->properties == first && first->next == last && last->prev == first);
    assert(middle->parent == NULL && middle->prev == NULL && middle->next == NULL);
    assert(middle->doc == doc && middle->ns == root->nsDef);
    assert(middle->_private == &marker);
    assert_value(middle, "2");
    xmlUnlinkNode((xmlNodePtr)middle);
    assert(root->properties == first && first->next == last && last->prev == first);
    assert(xmlNodeSetContent((xmlNodePtr)middle, BAD_CAST "changed&amp;value") == 0);
    assert_value(middle, "changed&value");

    xmlUnlinkNode((xmlNodePtr)first);
    assert(root->properties == last && last->prev == NULL && last->next == NULL);
    xmlUnlinkNode((xmlNodePtr)last);
    assert(root->properties == NULL);
    assert(first->parent == NULL && first->prev == NULL && first->next == NULL);
    assert(last->parent == NULL && last->prev == NULL && last->next == NULL);
    assert(root->children == target && root->last == target && target->parent == root);
    assert(xmlAddChild(root, (xmlNodePtr)first) == (xmlNodePtr)first);
    assert(xmlAddChild(root, (xmlNodePtr)last) == (xmlNodePtr)last);
    assert(xmlAddChild(target, (xmlNodePtr)middle) == (xmlNodePtr)middle);
    xmlUnlinkNode((xmlNodePtr)last);
    assert(root->properties == first && first->next == NULL);
    assert(xmlAddChild(target, (xmlNodePtr)last) == (xmlNodePtr)last);
    assert(target->properties == middle && middle->next == last && last->prev == middle);
    xmlUnlinkNode((xmlNodePtr)middle);
    assert(target->properties == last && last->prev == NULL);
    assert(xmlAddChild(root, (xmlNodePtr)middle) == (xmlNodePtr)middle);
    assert(first->next == middle && middle->prev == first && middle->next == NULL);
    assert(middle->_private == &marker && middle->doc == doc);
    assert_value(first, "1");
    assert_value(last, "3");
    assert_round_trip(doc, "middle", "urn:attrs", "changed&value");
    xmlFreeDoc(doc);
}

static void test_attach_duplicate_tail(void) {
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlAttrPtr first, last;
    assert(root);
    first = xmlNewProp(root, BAD_CAST "a", BAD_CAST "first");
    last = xmlNewProp(root, BAD_CAST "a", BAD_CAST "last");
    assert(first && last);
    assert(xmlAddChild(root, (xmlNodePtr)last) == (xmlNodePtr)last);
    assert(root->properties == first && first->next == last && last->prev == first);
    assert(xmlAddChild(root, (xmlNodePtr)first) == (xmlNodePtr)first);
    assert(root->properties == last && last->next == first && first->prev == last);
    assert(last->prev == NULL && first->next == NULL);
    xmlFreeNode(root);
}

#ifndef XML3_REFERENCE_TEST
static void test_unlinked_attribute_lifetime(void) {
    static const char input[] = "<root xmlns:p='urn:attrs' p:a='before'/>";
    for (int parsed = 0; parsed < 2; ++parsed) {
        xmlDocPtr doc;
        xmlNodePtr root, text;
        xmlAttrPtr attr;
        if (parsed) {
            doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
            assert(doc);
            root = xmlDocGetRootElement(doc);
            attr = root->properties;
        } else {
            xmlNsPtr ns;
            doc = xmlNewDoc(NULL);
            root = xmlNewNode(NULL, BAD_CAST "root");
            assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
            ns = xmlNewNs(root, BAD_CAST "urn:attrs", BAD_CAST "p");
            assert(ns);
            attr = xmlNewNsProp(root, ns, BAD_CAST "a", BAD_CAST "before");
        }
        assert(attr);
        xmlUnlinkNode((xmlNodePtr)attr);
        assert(root->properties == NULL && attr->parent == NULL);
        xmlFreeDoc(doc);
        assert(strcmp((const char *)attr->ns->href, "urn:attrs") == 0);
        assert(strcmp((const char *)attr->ns->prefix, "p") == 0);
        assert_value(attr, "before");
        assert(xmlNodeSetContent((xmlNodePtr)attr, BAD_CAST "after&amp;free") == 0);
        assert_value(attr, "after&free");
        text = attr->children;
        xmlUnlinkNode(text);
        assert(attr->children == NULL && attr->last == NULL && text->parent == NULL);
        xmlFreeProp(attr);
        assert(xmlNodeAddContent(text, BAD_CAST "+tail") == 0);
        assert(strcmp((const char *)text->content, "after&free+tail") == 0);
        xmlFreeNode(text);
    }
}

static void assert_tree_error(void);

static void test_unlink_rejections(void) {
    static const char input[] = "<root xmlns:p='urn:attrs' p:a='keep'/>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlAttrPtr attr;
    xmlNode unmanaged = {0};
    assert(doc);
    root = xmlDocGetRootElement(doc);
    attr = root->properties;
    xmlUnlinkNode((xmlNodePtr)doc);
    assert_tree_error();
    xmlUnlinkNode((xmlNodePtr)root->nsDef);
    assert_tree_error();
    xmlUnlinkNode(&unmanaged);
    assert_tree_error();
    assert(root->properties == attr && attr->parent == root);
    assert_value(attr, "keep");
    xmlResetLastError();
    xmlUnlinkNode(NULL);
    xmlUnlinkNode((xmlNodePtr)attr);
    assert(xmlGetLastError() == NULL && root->properties == NULL);
    xmlFreeProp(attr);
    xmlFreeDoc(doc);
}

static void test_attach_cross_document_rejection(void) {
    static const char input[] = "<source a='copied'><left/></source>";
    xmlDocPtr source_doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlDocPtr target_doc = xmlNewDoc(NULL);
    xmlNodePtr target = xmlNewNode(NULL, BAD_CAST "target");
    xmlNodePtr source;
    xmlAttrPtr attr, old, tail;
    assert(source_doc && target_doc && target);
    assert(xmlDocSetRootElement(target_doc, target) == NULL);
    source = xmlDocGetRootElement(source_doc);
    attr = source->properties;
    old = xmlNewProp(target, BAD_CAST "a", BAD_CAST "old");
    tail = xmlNewProp(target, BAD_CAST "tail", BAD_CAST "keep");
    assert(attr && old && tail);
    assert(xmlAddChild(target, (xmlNodePtr)attr) == NULL);
    assert(source->properties == attr && source->children != NULL);
    assert(target->properties == old && old->next == tail && tail->prev == old);
    assert(attr->parent == source && attr->prev == NULL && attr->next == NULL);
    assert(attr->doc == source_doc && attr->children->doc == source_doc);
    assert_value(attr, "copied");
    assert_value(old, "old");
    xmlFreeDoc(source_doc);
    assert_round_trip(target_doc, "a", NULL, "old");
    xmlFreeDoc(target_doc);
}

static void test_attach_rejections_and_namespace_lifetime(void) {
    xmlDocPtr target_doc = xmlNewDoc(NULL);
    xmlNodePtr target = xmlNewNode(NULL, BAD_CAST "target");
    xmlNodePtr text = xmlNewText(BAD_CAST "unchanged");
    xmlNode unmanaged = {0};
    xmlNodePtr source;
    xmlAttrPtr attr, old;
    xmlNsPtr ns, source_ns;
    assert(target_doc && target && text);
    assert(xmlDocSetRootElement(target_doc, target) == NULL);
    source = xmlNewChild(target, NULL, BAD_CAST "source", NULL);
    assert(source);
    source_ns = xmlNewNs(source, BAD_CAST "urn:move", BAD_CAST "p");
    ns = xmlNewNs(target, BAD_CAST "urn:move", BAD_CAST "p");
    assert(source_ns && ns);
    attr = xmlNewNsProp(source, source_ns, BAD_CAST "a", BAD_CAST "kept");
    old = xmlNewNsProp(target, ns, BAD_CAST "a", BAD_CAST "old");
    assert(attr && old);
    assert(xmlAddChild(NULL, (xmlNodePtr)attr) == NULL);
    assert(xmlAddChild((xmlNodePtr)target_doc, (xmlNodePtr)attr) == NULL);
    assert(xmlAddChild(text, (xmlNodePtr)attr) == NULL);
    assert(xmlAddChild((xmlNodePtr)old, (xmlNodePtr)attr) == NULL);
    assert(xmlAddChild(&unmanaged, (xmlNodePtr)attr) == NULL);
    assert(xmlAddChild(target, &unmanaged) == NULL);
    assert(source->properties == attr && attr->parent == source);
    assert(attr->prev == NULL && attr->next == NULL && attr->doc == target_doc);
    assert(target->properties == old && old->parent == target && old->next == NULL);
    assert_value(attr, "kept");
    assert(strcmp((const char *)text->content, "unchanged") == 0);
    xmlFreeNode(text);
    assert(xmlAddChild(target, (xmlNodePtr)attr) == (xmlNodePtr)attr);
    assert(target->properties == attr && attr->ns == source_ns);
    assert(source->properties == NULL);
    xmlFreeNode(source);
    assert(strcmp((const char *)attr->ns->href, "urn:move") == 0);
    assert_value(attr, "kept");
    assert_round_trip(target_doc, "a", "urn:move", "kept");
    xmlUnlinkNode(target);
    xmlFreeDoc(target_doc);
    assert(xmlNodeSetContent((xmlNodePtr)attr, BAD_CAST "after&amp;free") == 0);
    assert_value(attr, "after&free");
    assert(strcmp((const char *)attr->ns->href, "urn:move") == 0);
    xmlFreeNode(target);
    xmlResetLastError();
}

static void assert_tree_error(void) {
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->domain == XML_FROM_TREE);
    assert(xmlGetLastError()->code == 115);
    xmlResetLastError();
}

static void test_rejections_and_safe_free(void) {
    static const char input[] = "<r xmlns:p='urn:attrs' p:a='keep' a='remove'/>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlAttrPtr namespaced, plain, freed_namespaced;
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    namespaced = root->properties;
    plain = namespaced->next;
    assert(xmlSetProp(root, BAD_CAST "p:a", BAD_CAST "bad") == namespaced);
    assert_value(namespaced, "bad");
    assert(xmlNewProp(root, BAD_CAST "p:b", BAD_CAST "bad") == NULL);
    assert_tree_error();
    assert(xmlUnsetProp(root, BAD_CAST "p:a") == -1);
    assert_tree_error();
    assert(xmlNewProp(root, NULL, BAD_CAST "bad") == NULL);
    assert_tree_error();
    assert(xmlSetProp(NULL, BAD_CAST "a", BAD_CAST "bad") == NULL);
    assert_tree_error();
    assert(xmlNewProp((xmlNodePtr)doc, BAD_CAST "a", BAD_CAST "bad") == NULL);
    assert_tree_error();
    assert(xmlNewProp((xmlNodePtr)root->nsDef, BAD_CAST "a", NULL) == NULL);
    assert_tree_error();
    assert(xmlRemoveProp(namespaced) == 0);
    assert(root->properties == plain && plain->prev == NULL);
    freed_namespaced =
        xmlNewNsProp(root, root->nsDef, BAD_CAST "b", BAD_CAST "free");
    assert(freed_namespaced != NULL && freed_namespaced->next == NULL);
    xmlFreeProp(freed_namespaced);
    assert(root->properties == plain && plain->next == NULL);
    xmlFreeProp((xmlAttrPtr)root->nsDef);
    assert_tree_error();
    xmlFreeProp((xmlAttrPtr)root);
    assert_tree_error();
    assert(root->properties == plain && plain->prev == NULL);
    assert_value(plain, "remove");
    xmlFreeProp(plain);
    assert(root->properties == NULL);
    xmlFreeDoc(doc);
}

static void test_detached_lifetime_and_errors(void) {
    static const char input[] = "<r><item a='old'/></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr item, text;
    xmlAttrPtr attr;
    int code;
    assert(doc != NULL);
    item = xmlDocGetRootElement(doc)->children;
    xmlUnlinkNode(item);
    xmlFreeDoc(doc);
    attr = item->properties;
    assert(xmlSetProp(item, BAD_CAST "a", BAD_CAST "survives") == attr);
    text = attr->children;
    xmlUnlinkNode(text);
    assert(xmlRemoveProp(attr) == 0 && item->properties == NULL);
    xmlFreeNode(item);
    assert(strcmp((const char *)text->content, "survives") == 0);
    xmlFreeNode(text);

    assert(xmlReadMemory("<broken>", 8, NULL, NULL, 0) == NULL);
    code = xmlGetLastError()->code;
    item = xmlNewNode(NULL, BAD_CAST "item");
    assert(item != NULL);
    attr = xmlNewProp(item, BAD_CAST "a", BAD_CAST "v");
    assert(attr != NULL && xmlGetLastError()->code == code);
    assert(xmlSetProp(item, BAD_CAST "a", BAD_CAST "w") == attr);
    assert(xmlGetLastError()->code == code);
    assert(xmlUnsetProp(item, BAD_CAST "absent") == -1);
    assert(xmlGetLastError()->code == code);
    assert(xmlRemoveProp(attr) == 0 && xmlGetLastError()->code == code);
    xmlFreeNode(item);
    xmlResetLastError();
}
#endif

int main(void) {
    check_reference_version();
    test_edit_flow();
    test_parsed_attributes();
    test_standalone_attributes();
    test_attach_attributes();
    test_attach_namespace_attributes();
    test_attach_duplicate_tail();
    test_unlink_attributes();
    test_add_attribute_sibling();
#ifndef XML3_REFERENCE_TEST
    test_unlinked_attribute_lifetime();
    test_unlink_rejections();
    test_attach_cross_document_rejection();
    test_attach_rejections_and_namespace_lifetime();
    test_rejections_and_safe_free();
    test_detached_lifetime_and_errors();
#endif
    puts("Attribute editing tests passed");
    return 0;
}
