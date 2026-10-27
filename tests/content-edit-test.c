#include <libxml/parser.h>
#include <libxml/tree.h>

#include <assert.h>
#include <stdio.h>
#include <string.h>

static void assert_content(xmlNodePtr node, const char *expected) {
    xmlChar *content = xmlNodeGetContent(node);
    assert(content != NULL);
    assert(strcmp((const char *)content, expected) == 0);
    xmlFree(content);
}

static void test_element_and_attribute_append(void) {
    static const char input[] = "<root a='v'>left</root>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root;
    xmlNodePtr trailing;
    xmlAttrPtr attr;
    xmlNodePtr attr_text;
    xmlChar *memory = NULL;
    int size = 0;
    xmlDocPtr reparsed;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    trailing = root->children;
    attr = root->properties;
    attr_text = attr->children;
    assert(xmlNodeAddContent(root, BAD_CAST "é<&") == 0);
    assert(root->children == trailing && root->last == trailing);
    assert_content(root, "lefté<&");
    assert(xmlNodeAddContent((xmlNodePtr)attr, BAD_CAST "x<&") == 0);
    assert(root->properties == attr);
    assert(attr->children == attr_text && attr->last == attr_text);
    assert(strcmp((const char *)attr->children->content, "vx<&") == 0);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && size > 0);
    assert(strstr((const char *)memory, "lefté&lt;&amp;") != NULL);
    assert(strstr((const char *)memory, "a=\"vx&lt;&amp;\"") != NULL);
    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed != NULL);
    assert_content(xmlDocGetRootElement(reparsed), "lefté<&");
    xmlFreeDoc(reparsed);
    xmlFree(memory);
    xmlFreeDoc(doc);
}

static void test_new_child_after_non_text(void) {
    xmlDocPtr doc = xmlReadMemory("<r><!--c--></r>", 15, NULL, NULL, 0);
    xmlNodePtr root;
    xmlNodePtr comment;
    xmlNodePtr text;
    xmlAttrPtr attr;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    comment = root->children;
    assert(comment != NULL && comment->type == XML_COMMENT_NODE);
    assert(xmlNodeAddContent(root, BAD_CAST "tail") == 0);
    text = root->last;
    assert(text != comment && text->type == XML_TEXT_NODE);
    assert(root->children == comment && comment->next == text);
    assert_content(text, "tail");
    attr = xmlNewProp(root, BAD_CAST "empty", NULL);
    assert(attr != NULL && attr->children == NULL);
    assert(xmlNodeAddContent((xmlNodePtr)attr, BAD_CAST "value") == 0);
    assert(attr->children != NULL && attr->children == attr->last);
    assert(attr->children->type == XML_TEXT_NODE);
    assert(strcmp((const char *)attr->children->content, "value") == 0);
    xmlFreeDoc(doc);
}

static void test_scalar_nodes_and_aliasing(void) {
    xmlNodePtr text = xmlNewText(BAD_CAST "ab");
    static const char input[] = "<r><![CDATA[c]]></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr cdata;
    xmlNodePtr comment = xmlNewComment(BAD_CAST "note");
    xmlNodePtr pi = xmlNewPI(BAD_CAST "target", BAD_CAST "data");
    xmlNodePtr empty_text = xmlNewText(NULL);

    assert(text != NULL && doc != NULL && comment != NULL && pi != NULL &&
           empty_text != NULL);
    assert(xmlNodeAddContent(text, text->content) == 0);
    assert(strcmp((const char *)text->content, "abab") == 0);
    assert(xmlNodeAddContent(empty_text, BAD_CAST "filled") == 0);
    assert(strcmp((const char *)empty_text->content, "filled") == 0);
    cdata = xmlDocGetRootElement(doc)->children;
    assert(cdata != NULL && cdata->type == XML_CDATA_SECTION_NODE);
    assert(xmlNodeAddContent(cdata, BAD_CAST "d") == 0);
    assert(strcmp((const char *)cdata->content, "cd") == 0);
    assert(xmlNodeAddContent(comment, BAD_CAST " &") == 0);
    assert(strcmp((const char *)comment->content, "note &") == 0);
    assert(xmlNodeAddContent(pi, BAD_CAST " more") == 0);
    assert(strcmp((const char *)pi->content, "data more") == 0);
    assert(xmlNodeAddContent(text, NULL) == 0);
    assert(xmlNodeAddContent(text, BAD_CAST "") == 0);
    assert(strcmp((const char *)text->content, "abab") == 0);
    assert(xmlNodeAddContent(NULL, BAD_CAST "x") == 1);

    xmlFreeNode(text);
    xmlFreeNode(empty_text);
    xmlFreeNode(comment);
    xmlFreeNode(pi);
    xmlFreeDoc(doc);
}

static void test_detached_lifetime(void) {
    xmlDocPtr doc = xmlReadMemory("<r>old</r>", 10, NULL, NULL, 0);
    xmlNodePtr root;
    xmlNodePtr text;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    text = root->children;
    xmlUnlinkNode(text);
    xmlFreeDoc(doc);
    assert(xmlNodeAddContent(text, BAD_CAST "-new") == 0);
    assert(strcmp((const char *)text->content, "old-new") == 0);
    xmlFreeNode(text);
}

#ifndef XML3_REFERENCE_TEST
static void test_invalid_facade_and_document_noop(void) {
    xmlNode invalid = {0};
    xmlDocPtr doc = xmlNewDoc(NULL);

    assert(doc != NULL);
    invalid.type = XML_TEXT_NODE;
    assert(xmlNodeAddContent(&invalid, NULL) == 1);
    assert(xmlNodeAddContent(&invalid, BAD_CAST "x") == 1);
    assert(xmlNodeAddContent((xmlNodePtr)doc, BAD_CAST "ignored") == 0);
    assert(xmlDocGetRootElement(doc) == NULL);
    xmlFreeDoc(doc);
}

static void test_invalid_comment_serialization(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNodePtr comment = xmlNewComment(BAD_CAST "bad");
    xmlChar *memory = (xmlChar *)1;
    int size = 77;

    assert(doc != NULL && root != NULL && comment != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlAddChild(root, comment) == comment);
    assert(xmlNodeAddContent(comment, BAD_CAST "--") == 0);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory == NULL && size == 0);
    xmlFreeDoc(doc);
}
#endif

int main(void) {
    assert(xmlNodeAddContent(NULL, NULL) == 1);
    test_element_and_attribute_append();
    test_new_child_after_non_text();
    test_scalar_nodes_and_aliasing();
    test_detached_lifetime();
#ifndef XML3_REFERENCE_TEST
    test_invalid_facade_and_document_noop();
    test_invalid_comment_serialization();
#endif
    puts("content append tests passed");
    return 0;
}
