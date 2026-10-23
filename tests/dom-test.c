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
#endif

int main(void) {
    test_constructors_and_root_replacement();
    test_text_merge_and_edit_flow();
    test_parsed_unlink_and_reinsert();
#ifndef XML3_REFERENCE_TEST
    test_sticky_mutator_errors();
    test_safe_ownership();
#endif
    puts("DOM ownership and editing tests passed");
    return 0;
}
