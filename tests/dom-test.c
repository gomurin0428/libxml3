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

static void assert_path(xmlNodePtr node, const char *expected) {
    xmlChar *path = xmlGetNodePath(node);
    assert(path != NULL);
    if (strcmp((const char *)path, expected) != 0)
        fprintf(stderr, "path mismatch: got %s expected %s\n",
                (const char *)path, expected);
    assert(strcmp((const char *)path, expected) == 0);
    xmlFree(path);
}

static void assert_raw_list(const xmlNode *list, int inline_value,
                            const char *expected) {
    xmlChar *value = xmlNodeListGetRawString(NULL, list, inline_value);
    assert(value && strcmp((const char *)value, expected) == 0);
    xmlFree(value);
}

static void assert_list_string(xmlDocPtr doc, const xmlNode *list,
                               int inline_value, const char *expected) {
    xmlChar *value = xmlNodeListGetString(doc, list, inline_value);
    assert(value && strcmp((const char *)value, expected) == 0);
    xmlFree(value);
}

static void test_node_list_string(void) {
    static const char value[] = "<&>\"'\r\n\té中🙂";
    static const char escaped[] =
        "&lt;&amp;&gt;\"'&#13;\n\t&#xE9;&#x4E2D;&#x1F642;";
    static const char attr_escaped[] =
        "&lt;&amp;&gt;&quot;'&#13;&#10;&#9;&#xE9;&#x4E2D;&#x1F642;";
    static const char encoded_doc[] =
        "<?xml version='1.0' encoding='UTF-8'?><r>é</r>";
    xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNodePtr text, restored, boundary;
    xmlAttrPtr attr;
    xmlChar *copy;
    char buffer[512];
    xmlDocPtr reparsed;
    assert(doc && root);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    text = xmlNewDocText(doc, BAD_CAST value);
    assert(text && xmlAddChild(root, text) == text);
    assert_list_string(doc, text, 0, escaped);
    assert_list_string(NULL, text, -1, value);
    assert_list_string((xmlDocPtr)1, text, 1, value);
    assert_list_string(doc, root, 0, "");
    assert(xmlNodeListGetString((xmlDocPtr)1, NULL, 0) == NULL);
    attr = xmlNewProp(root, BAD_CAST "a", BAD_CAST value);
    assert(attr && attr->children);
    assert_list_string(doc, attr->children, 0, attr_escaped);
    assert_list_string(doc, attr->children, 1, value);
    copy = xmlNodeListGetString(doc, attr->children, 0);
    assert(copy);
    assert(snprintf(buffer, sizeof(buffer), "<r a=\"%s\"/>", copy) > 0);
    reparsed = xmlReadMemory(buffer, (int)strlen(buffer), NULL, NULL, 0);
    assert(reparsed && xmlDocGetRootElement(reparsed)->properties);
    assert_text((xmlNodePtr)xmlDocGetRootElement(reparsed)->properties, value);
    xmlFreeDoc(reparsed);
    xmlUnlinkNode((xmlNodePtr)attr);
    assert_list_string(NULL, attr->children, 0, attr_escaped);
    xmlFreeProp(attr);
#ifndef XML3_REFERENCE_TEST
    xmlResetLastError();
    assert(xmlNodeListGetString((xmlDocPtr)1, text, 0) == NULL);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    assert(xmlNodeListGetString((xmlDocPtr)root, text, 0) == NULL);
    xmlUnlinkNode(root);
    xmlFreeDoc(doc);
    assert_list_string(NULL, text, 0, escaped);
    xmlFreeNode(root);
    xmlResetLastError();
#else
    xmlFreeDoc(doc);
#endif
    restored = xmlStringGetNodeList(NULL, copy);
    xmlFree(copy);
    assert(restored);
    assert_text(restored, value);
    xmlFreeNodeList(restored);
    boundary = xmlNewText(BAD_CAST
        "\xC2\x80\xDF\xBF\xE0\xA0\x80\xF0\x90\x80\x80\xF4\x8F\xBF\xBF");
    assert(boundary);
    assert_list_string(NULL, boundary, 0,
                      "&#x80;&#x7FF;&#x800;&#x10000;&#x10FFFF;");
    xmlFreeNode(boundary);
    doc = xmlReadMemory(encoded_doc, (int)strlen(encoded_doc), NULL, NULL, 0);
    assert(doc);
    text = xmlDocGetRootElement(doc)->children;
    assert_list_string(NULL, text, 0, "&#xE9;");
#ifdef XML3_REFERENCE_TEST
    assert_list_string(doc, text, 0, "é");
#else
    assert_list_string(doc, text, 0, "&#xE9;");
#endif
    xmlFreeDoc(doc);
}

static void test_raw_node_list(void) {
    static const char input[] =
        "<r>one&lt;&amp;\"&#13;\t\né<!--ignored--><e>nested</e>"
        "<![CDATA[two<>]]><?p ignored?>tail</r>";
    static const char expected[] = "one<&\"\r\t\nétwo<>tail";
    static const char encoded[] = "one&lt;&amp;&quot;&#13;\t\nétwo&lt;&gt;tail";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlNodePtr root, first, restored, empty;
    xmlAttrPtr attr;
    xmlChar *raw, *escaped;
    assert(doc);
    root = xmlDocGetRootElement(doc);
    first = root->children;
    assert(first && first->next && first->next->type == XML_COMMENT_NODE);
    raw = xmlNodeListGetRawString((const xmlDoc *)1, first, -1);
    escaped = xmlNodeListGetRawString(doc, first, 0);
    assert(raw && escaped && raw != first->content);
    assert(strcmp((const char *)raw, expected) == 0);
    assert(strcmp((const char *)escaped, encoded) == 0);
    assert_raw_list(first->next, 1, "two<>tail");
    assert_raw_list(root, 0, "");
    assert_raw_list(root->last, 1, "tail");
    assert(xmlNodeListGetRawString(doc, NULL, 0) == NULL);
    assert(xmlNodeListGetRawString(doc, NULL, 1) == NULL);
    attr = xmlNewProp(root, BAD_CAST "a", BAD_CAST "A\"&\r\t\né");
    assert(attr && attr->children);
    assert_raw_list(attr->children, 1, "A\"&\r\t\né");
    assert_raw_list(attr->children, 0, "A&quot;&amp;&#13;\t\né");
    empty = xmlNewText(NULL);
    assert(empty);
    assert_raw_list(empty, 0, "");
    assert_raw_list(empty, 1, "");
    xmlFreeNode(empty);
#ifndef XML3_REFERENCE_TEST
    xmlUnlinkNode(root);
    xmlFreeDoc(doc);
    assert_raw_list(first, 0, encoded);
    xmlFreeNode(root);
#else
    xmlFreeDoc(doc);
#endif
    assert(strcmp((const char *)raw, expected) == 0);
    restored = xmlStringGetNodeList(NULL, escaped);
    assert(restored);
    xmlFree(escaped);
    assert_text(restored, expected);
    xmlFreeNodeList(restored);
    xmlFree(raw);
}

#ifndef XML3_REFERENCE_TEST
static void test_raw_node_list_rejections(void) {
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr first = xmlNewText(BAD_CAST "\xC3");
    xmlNodePtr second = xmlNewText(BAD_CAST "\xA9");
    assert(root && first && second);
    assert(xmlAddChild(root, first) == first);
    assert(xmlAddNextSibling(first, second) == second);
    assert(first->next == second);
    assert_raw_list(first, 1, "é");
    xmlResetLastError();
    assert(xmlNodeListGetRawString(NULL, first, 0) == NULL);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    assert(xmlNodeListGetString(NULL, first, 0) == NULL);
    assert(root->children == first && root->last == second && first->next == second);
    assert(xmlNodeSetContent(first, BAD_CAST "valid") == 0);
    assert(xmlNodeSetContent(second, BAD_CAST " &") == 0);
    assert_raw_list(first, 0, "valid &amp;");
    assert(xmlNodeSetContent(first, BAD_CAST "\x01") == 0);
    assert_raw_list(first, 1, "\x01 &");
    assert(xmlNodeListGetRawString(NULL, first, 0) == NULL);
    xmlResetLastError();
    assert(xmlNodeListGetString(NULL, first, 0) == NULL);
    assert(xmlNodeListGetRawString(NULL, (const xmlNode *)1, 1) == NULL);
    assert(xmlNodeListGetString(NULL, (const xmlNode *)1, 1) == NULL);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    xmlFreeNode(root);
    xmlResetLastError();
}
#endif

#ifndef XML3_REFERENCE_TEST
static void assert_invalid_path(xmlNodePtr node) {
    xmlResetLastError();
    assert(xmlGetNodePath(node) == NULL);
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->domain == XML_FROM_TREE);
    assert(xmlGetLastError()->code == 115);
    xmlResetLastError();
}
#endif

static void test_node_paths(void) {
    xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr first;
    xmlNodePtr second;
    xmlNodePtr single;
    xmlNodePtr text;
    xmlNodePtr cdata;
    xmlNodePtr comment;
    xmlNodePtr second_comment;
    xmlNodePtr pi;
    xmlNodePtr second_pi;
    xmlAttrPtr attr;
    xmlChar *owned;

    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlGetNodePath(NULL) == NULL);
    assert_path((xmlNodePtr)doc, "/");
    assert_path(root, "/root");
    first = xmlNewChild(root, NULL, BAD_CAST "item", NULL);
    second = xmlNewChild(root, NULL, BAD_CAST "item", NULL);
    single = xmlNewChild(root, NULL, BAD_CAST "single", NULL);
    assert(first != NULL && second != NULL && single != NULL);
    assert_path(first, "/root/item[1]");
    assert_path(second, "/root/item[2]");
    assert_path(single, "/root/single");

    attr = xmlNewProp(root, BAD_CAST "id", BAD_CAST "value");
    assert(attr != NULL);
    assert_path((xmlNodePtr)attr, "/root/@id");
    assert(attr->children != NULL);
    assert_path(attr->children, "/root/@id/text()");

    text = xmlNewText(BAD_CAST "text");
    cdata = xmlNewCDataBlock(doc, BAD_CAST "cdata", 5);
    comment = xmlNewComment(BAD_CAST "comment");
    second_comment = xmlNewComment(BAD_CAST "other");
    pi = xmlNewPI(BAD_CAST "target", BAD_CAST "data");
    second_pi = xmlNewPI(BAD_CAST "target", BAD_CAST "more");
    assert(text != NULL && cdata != NULL && comment != NULL
           && second_comment != NULL && pi != NULL && second_pi != NULL);
    assert(xmlAddChild(root, text) == text);
    assert(xmlAddChild(root, cdata) == cdata);
    assert(xmlAddChild(root, comment) == comment);
    assert(xmlAddChild(root, second_comment) == second_comment);
    assert(xmlAddChild(root, pi) == pi);
    assert(xmlAddChild(root, second_pi) == second_pi);
    assert_path(text, "/root/text()[1]");
    assert_path(cdata, "/root/text()[2]");
    assert_path(comment, "/root/comment()[1]");
    assert_path(second_comment, "/root/comment()[2]");
    assert_path(pi, "/root/processing-instruction('target')[1]");
    assert_path(second_pi, "/root/processing-instruction('target')[2]");

    xmlUnlinkNode(first);
    assert_path(second, "/root/item");
    assert(xmlAddPrevSibling(second, first) == first);
    assert_path(second, "/root/item[2]");
    for (int i = 0; i < 10; i++) {
        second = xmlNewChild(root, NULL, BAD_CAST "item", NULL);
        assert(second != NULL);
    }
    assert_path(second, "/root/item[12]");

    {
        xmlNsPtr prefixed = xmlNewNs(root, BAD_CAST "urn:a", BAD_CAST "p");
        xmlNodePtr named = xmlNewNode(prefixed, BAD_CAST "named");
        xmlAttrPtr namespaced_attr;
        assert(prefixed != NULL && named != NULL);
        assert(xmlGetNodePath((xmlNodePtr)prefixed) == NULL);
        assert(xmlAddChild(root, named) == named);
        assert_path(named, "/root/p:named");
        namespaced_attr =
            xmlNewNsProp(root, prefixed, BAD_CAST "id", BAD_CAST "value");
        assert(namespaced_attr != NULL && namespaced_attr->children != NULL);
        assert_path((xmlNodePtr)namespaced_attr, "/root/@p:id");
        assert_path(namespaced_attr->children, "/root/@p:id/text()");
    }
    {
        xmlDocPtr ns_doc = xmlNewDoc(BAD_CAST "1.0");
        xmlNodePtr ns_root = xmlNewNode(NULL, BAD_CAST "r");
        xmlNsPtr default_ns;
        xmlNsPtr other_ns;
        xmlNodePtr wildcard;
        xmlNodePtr other;
        xmlNodePtr other_namespaced;
        assert(ns_doc != NULL && ns_root != NULL);
        assert(xmlDocSetRootElement(ns_doc, ns_root) == NULL);
        default_ns = xmlNewNs(ns_root, BAD_CAST "urn:one", NULL);
        other_ns = xmlNewNs(ns_root, BAD_CAST "urn:other", BAD_CAST "x");
        wildcard = xmlNewNode(default_ns, BAD_CAST "wanted");
        other = xmlNewChild(ns_root, NULL, BAD_CAST "other", NULL);
        other_namespaced = xmlNewNode(other_ns, BAD_CAST "third");
        assert(default_ns != NULL && other_ns != NULL && wildcard != NULL
               && other != NULL && other_namespaced != NULL);
        assert(xmlAddPrevSibling(other, wildcard) == wildcard);
        assert(xmlAddChild(ns_root, other_namespaced) == other_namespaced);
        assert_path(wildcard, "/r/*[1]");
        xmlFreeDoc(ns_doc);
    }
    {
        xmlNodePtr one_node = xmlNewNode(NULL, BAD_CAST "same");
        xmlNodePtr two_node = xmlNewNode(NULL, BAD_CAST "same");
        xmlNsPtr one;
        xmlNsPtr two;
        assert(one_node != NULL && two_node != NULL);
        assert(xmlAddChild(root, one_node) == one_node);
        assert(xmlAddChild(root, two_node) == two_node);
        one = xmlNewNs(one_node, BAD_CAST "urn:one", BAD_CAST "q");
        two = xmlNewNs(two_node, BAD_CAST "urn:two", BAD_CAST "q");
        assert(one != NULL && two != NULL);
        xmlSetNs(one_node, one);
        xmlSetNs(two_node, two);
        assert_path(one_node, "/root/q:same[1]");
        assert_path(two_node, "/root/q:same[2]");
    }
    {
        xmlNodePtr deep = root;
        xmlChar *path;
        for (int i = 0; i < 24; i++) {
            deep = xmlNewChild(deep, NULL, BAD_CAST "deepname", NULL);
            assert(deep != NULL);
        }
        path = xmlGetNodePath(deep);
        assert(path != NULL && strlen((const char *)path) == 221);
        xmlFree(path);
    }
    {
        xmlNodePtr unicode = xmlNewChild(root, NULL, BAD_CAST "名", NULL);
        assert(unicode != NULL);
        assert_path(unicode, "/root/名");
        owned = xmlGetNodePath(unicode);
        assert(owned != NULL);
        xmlFreeDoc(doc);
        assert(strcmp((const char *)owned, "/root/名") == 0);
        xmlFree(owned);
        return;
    }
}

static void test_node_set_name(void) {
    xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr element;
    xmlNodePtr child;
    xmlAttrPtr attr;
    xmlNodePtr pi;
    xmlNsPtr ns;
    xmlChar *dump = NULL;
    int dump_size = 0;
    char caller_name[] = "caller";

    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    ns = xmlNewNs(root, BAD_CAST "urn:name", BAD_CAST "p");
    element = xmlNewChild(root, ns, BAD_CAST "old", BAD_CAST "value");
    attr = xmlNewNsProp(root, ns, BAD_CAST "id", BAD_CAST "attribute");
    pi = xmlNewPI(BAD_CAST "target", BAD_CAST "data");
    assert(ns != NULL && element != NULL && attr != NULL && pi != NULL);
    assert(xmlAddChild(root, pi) == pi);
    child = element->children;

    xmlNodeSetName(element, BAD_CAST "renamed");
    assert(element->name != NULL &&
           strcmp((const char *)element->name, "renamed") == 0);
    assert(element->parent == root && element->children == child);
    assert(child->parent == element && element->ns == ns);
    assert_path(element, "/root/p:renamed");
    assert_text(element, "value");

    xmlNodeSetName((xmlNodePtr)attr, BAD_CAST "key");
    assert(attr->parent == root && attr->children != NULL);
    assert(xmlHasNsProp(root, BAD_CAST "key", BAD_CAST "urn:name") == attr);
    assert_path((xmlNodePtr)attr, "/root/@p:key");
    assert_path(attr->children, "/root/@p:key/text()");

    xmlNodeSetName(element, element->name);
    assert(strcmp((const char *)element->name, "renamed") == 0);
    xmlNodeSetName(element, element->name + 1);
    assert(strcmp((const char *)element->name, "enamed") == 0);
    assert_path(element, "/root/p:enamed");
    xmlNodeSetName(element, BAD_CAST caller_name);
    caller_name[0] = 'x';
    assert(strcmp((const char *)element->name, "caller") == 0);
    xmlNodeSetName(element, BAD_CAST "名");
    assert(strcmp((const char *)element->name, "名") == 0);
    assert_path(element, "/root/p:名");

    xmlNodeSetName(pi, BAD_CAST "renamed-pi");
    assert(strcmp((const char *)pi->name, "renamed-pi") == 0);
    assert_text(pi, "data");
    xmlNodeSetContent(pi, BAD_CAST "pi-source");
    xmlNodeSetName(pi, pi->content);
    assert(strcmp((const char *)pi->name, "pi-source") == 0);
    xmlNodeSetContent(pi, BAD_CAST "updated");
    assert(strcmp((const char *)pi->name, "pi-source") == 0);
    assert_text(pi, "updated");
    assert_path(pi, "/root/processing-instruction('pi-source')");

    xmlResetLastError();
    xmlNodeSetName(NULL, BAD_CAST "ignored");
    xmlNodeSetName((xmlNodePtr)doc, BAD_CAST "ignored");
    xmlNodeSetName(root, NULL);
    assert(xmlGetLastError() == NULL);
    assert(strcmp((const char *)doc->version, "1.0") == 0);
    assert(strcmp((const char *)root->name, "root") == 0);

    xmlDocDumpMemoryEnc(doc, &dump, &dump_size, "UTF-8");
    assert(dump != NULL && dump_size > 0);
    {
        xmlDocPtr reparsed =
            xmlReadMemory((const char *)dump, dump_size, NULL, NULL, 0);
        assert(reparsed != NULL);
        assert(xmlDocGetRootElement(reparsed) != NULL);
        assert(strcmp((const char *)xmlDocGetRootElement(reparsed)->name,
                      "root") == 0);
        xmlFreeDoc(reparsed);
    }
    xmlFree(dump);
    xmlFreeDoc(doc);
}

#ifndef XML3_REFERENCE_TEST
static void assert_name_rejected(xmlNodePtr node, const xmlChar *candidate) {
    const xmlChar *old_name = node->name;
    const xmlChar *old_content = NULL;
    xmlNodePtr old_parent = node->parent;
    xmlNodePtr old_previous = node->prev;
    xmlNodePtr old_next = node->next;
    xmlNodePtr old_children = node->children;

    if (node->type != XML_ATTRIBUTE_NODE) {
        old_content = node->content;
    }
    xmlResetLastError();
    xmlNodeSetName(node, candidate);
    assert(xmlGetLastError() != NULL);
    assert(xmlGetLastError()->domain == XML_FROM_TREE);
    assert(xmlGetLastError()->code == 115);
    assert(node->name == old_name);
    if (node->type != XML_ATTRIBUTE_NODE) {
        assert(node->content == old_content);
    }
    assert(node->parent == old_parent && node->prev == old_previous);
    assert(node->next == old_next && node->children == old_children);
    xmlResetLastError();
}

static void test_node_set_name_rejections(void) {
    xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr element;
    xmlNodePtr pi;
    xmlAttrPtr plain;
    xmlAttrPtr first;
    xmlAttrPtr second;
    xmlAttrPtr other_uri;
    xmlNsPtr same_p;
    xmlNsPtr same_q;
    xmlNsPtr other;
    xmlNode foreign;
    xmlChar malformed[] = { (xmlChar)0xff, 0 };

    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    element = xmlNewChild(root, NULL, BAD_CAST "element", BAD_CAST "value");
    pi = xmlNewPI(BAD_CAST "target", BAD_CAST "value");
    plain = xmlNewProp(root, BAD_CAST "plain", BAD_CAST "value");
    same_p = xmlNewNs(root, BAD_CAST "urn:same", BAD_CAST "p");
    same_q = xmlNewNs(root, BAD_CAST "urn:same", BAD_CAST "q");
    other = xmlNewNs(root, BAD_CAST "urn:other", BAD_CAST "r");
    first = xmlNewNsProp(root, same_p, BAD_CAST "first", BAD_CAST "one");
    second = xmlNewNsProp(root, same_q, BAD_CAST "second", BAD_CAST "two");
    other_uri = xmlNewNsProp(root, other, BAD_CAST "third", BAD_CAST "three");
    assert(element != NULL && pi != NULL && plain != NULL);
    assert(same_p != NULL && same_q != NULL && other != NULL);
    assert(first != NULL && second != NULL && other_uri != NULL);

    assert_name_rejected(element, BAD_CAST "");
    assert_name_rejected(element, BAD_CAST "bad:name");
    assert_name_rejected(element, malformed);
    assert_name_rejected((xmlNodePtr)plain, BAD_CAST "xmlns");
    assert_name_rejected(pi, BAD_CAST "XML");
    assert_name_rejected(pi, BAD_CAST "bad'");
    assert_name_rejected((xmlNodePtr)second, BAD_CAST "first");
    xmlNodeSetName((xmlNodePtr)other_uri, BAD_CAST "first");
    assert(strcmp((const char *)other_uri->name, "first") == 0);

    memset(&foreign, 0, sizeof(foreign));
    xmlResetLastError();
    xmlNodeSetName(&foreign, BAD_CAST "foreign");
    assert(xmlGetLastError() != NULL && xmlGetLastError()->code == 115);
    xmlResetLastError();
    xmlNodeSetName(NULL, BAD_CAST "ignored");
    assert(xmlGetLastError() == NULL);
    xmlFreeNode(pi);
    xmlFreeDoc(doc);

    doc = xmlNewDoc(BAD_CAST "1.0");
    root = xmlNewNode(NULL, BAD_CAST "root");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    {
        xmlNsPtr retained_ns =
            xmlNewNs(root, BAD_CAST "urn:retained", BAD_CAST "p");
        xmlNodePtr retained =
            xmlNewChild(root, retained_ns, BAD_CAST "detached", BAD_CAST "old");
        xmlChar *path;
        assert(retained_ns != NULL && retained != NULL);
        xmlNodeSetName(retained, BAD_CAST "detached-renamed");
        assert(strcmp((const char *)retained->name, "detached-renamed") == 0);
        xmlUnlinkNode(retained);
        xmlFreeDoc(doc);
        assert(strcmp((const char *)retained->name, "detached-renamed") == 0);
        xmlNodeSetContent(retained, BAD_CAST "new");
        assert(strcmp((const char *)retained->name, "detached-renamed") == 0);
        xmlNodeSetName(retained, BAD_CAST "detached-again");
        path = xmlGetNodePath(retained);
        assert(path != NULL && strcmp((const char *)path, "/p:detached-again") == 0);
        xmlFree(path);
        assert_text(retained, "new");
        xmlFreeNode(retained);
    }
}
#endif

#ifndef XML3_REFERENCE_TEST
static void test_node_path_rejections(void) {
    xmlDocPtr doc = xmlNewDoc(BAD_CAST "1.0");
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
    xmlNodePtr invalid;
    xmlNsPtr invalid_ns;
    xmlNodePtr invalid_prefixed;
    xmlNodePtr invalid_pi;
    xmlNodePtr invalid_utf8;
    xmlNode fake;

    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    invalid = xmlNewNode(NULL, BAD_CAST "bad]");
    assert(invalid != NULL);
    assert_invalid_path(invalid);
    xmlFreeNode(invalid);
    invalid_pi = xmlNewPI(BAD_CAST "bad'", NULL);
    assert(invalid_pi != NULL);
    assert_invalid_path(invalid_pi);
    xmlFreeNode(invalid_pi);
    invalid_utf8 = xmlNewNode(NULL, BAD_CAST "\xff");
    assert(invalid_utf8 != NULL);
    assert_invalid_path(invalid_utf8);
    xmlFreeNode(invalid_utf8);
    invalid_ns = xmlNewNs(root, BAD_CAST "urn:bad", BAD_CAST "bad]");
    assert(invalid_ns != NULL);
    invalid_prefixed = xmlNewNode(invalid_ns, BAD_CAST "name");
    assert(invalid_prefixed != NULL);
    assert_invalid_path(invalid_prefixed);
    xmlFreeNode(invalid_prefixed);
    memset(&fake, 0, sizeof(fake));
    assert_invalid_path(&fake);
    assert_invalid_path((xmlNodePtr)invalid_ns);
    xmlFreeDoc(doc);

    doc = xmlNewDoc(BAD_CAST "1.0");
    root = xmlNewNode(NULL, BAD_CAST "root");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    {
        xmlNsPtr detached_ns =
            xmlNewNs(root, BAD_CAST "urn:detached", BAD_CAST "p");
        assert(detached_ns != NULL);
        invalid = xmlNewChild(root, detached_ns, BAD_CAST "detached", NULL);
    }
    assert(invalid != NULL);
    xmlUnlinkNode(invalid);
    xmlFreeDoc(doc);
    {
        xmlChar *path = xmlGetNodePath(invalid);
        assert(path != NULL && strcmp((const char *)path, "/p:detached") == 0);
        xmlFree(path);
    }
    xmlFreeNode(invalid);
}
#endif

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

static void test_replace_node_flow(void) {
    xmlDocPtr doc;
    xmlNodePtr root;
    xmlNodePtr first;
    xmlNodePtr middle;
    xmlNodePtr last;
    xmlNodePtr replacement;
    xmlNodePtr old;
    xmlNodePtr source;
    xmlNodePtr target;
    xmlNodePtr before;
    xmlNodePtr after;
    xmlNodePtr text;
    xmlNodePtr comment;
    xmlNodePtr right;
    xmlChar *bytes;
    int size;

    doc = xmlReadMemory("<r><a/><b/><c/></r>",
                        (int)strlen("<r><a/><b/><c/></r>"), NULL, NULL, 0);
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    first = root->children;
    middle = first->next;
    last = root->last;
    replacement = xmlNewNode(NULL, BAD_CAST "middle");
    assert(replacement != NULL);
    assert(xmlReplaceNode(middle, replacement) == middle);
    assert(root->children == first && root->last == last);
    assert(first->next == replacement && replacement->prev == first);
    assert(replacement->next == last && last->prev == replacement);
    assert(replacement->parent == root);
    assert(middle->parent == NULL && middle->prev == NULL && middle->next == NULL);
    xmlFreeNode(middle);
    assert(xmlNodeSetContent(replacement, BAD_CAST "edited") == 0);
    bytes = NULL;
    size = 0;
    xmlDocDumpMemoryEnc(doc, &bytes, &size, "UTF-8");
    assert(bytes != NULL && size > 0);
    assert(strstr((const char *)bytes, "<middle>edited</middle>") != NULL);
    xmlFree(bytes);
    xmlFreeDoc(doc);

    doc = xmlReadMemory("<r><a/><b/><c/></r>",
                        (int)strlen("<r><a/><b/><c/></r>"), NULL, NULL, 0);
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    old = root->children;
    replacement = xmlNewNode(NULL, BAD_CAST "first");
    assert(replacement != NULL);
    assert(xmlReplaceNode(old, replacement) == old);
    assert(root->children == replacement && replacement->prev == NULL);
    assert(replacement->next != NULL && replacement->next->prev == replacement);
    assert(root->last->next == NULL);
    xmlFreeNode(old);
    old = root->last;
    replacement = xmlNewNode(NULL, BAD_CAST "last");
    assert(replacement != NULL);
    assert(xmlReplaceNode(old, replacement) == old);
    assert(root->last == replacement && replacement->next == NULL);
    assert(replacement->prev != NULL && replacement->prev->next == replacement);
    xmlFreeNode(old);
    xmlFreeDoc(doc);

    doc = xmlReadMemory("<r><before/><source><inside/></source><target/><after/></r>",
                        (int)strlen("<r><before/><source><inside/></source><target/><after/></r>"),
                        NULL, NULL, 0);
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    before = root->children;
    source = before->next;
    target = source->next;
    after = root->last;
    xmlUnlinkNode(source);
    assert(before->next == target && target->prev == before);
    assert(source->parent == NULL && source->prev == NULL && source->next == NULL);
    assert(xmlReplaceNode(target, source) == target);
    assert(root->children == before && before->next == source);
    assert(source->parent == root && source->prev == before);
    assert(source->next == after && after->prev == source);
    assert(target->parent == NULL && target->prev == NULL && target->next == NULL);
    xmlFreeNode(target);
    xmlFreeDoc(doc);

    doc = xmlReadMemory("<r><source><move/></source><old/><after/></r>",
                        (int)strlen("<r><source><move/></source><old/><after/></r>"),
                        NULL, NULL, 0);
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    source = root->children;
    replacement = source->children;
    old = source->next;
    after = root->last;
    assert(source->last == replacement && replacement->parent == source);
    assert(xmlReplaceNode(old, replacement) == old);
    assert(source->children == NULL && source->last == NULL);
    assert(root->children == source && source->parent == root);
    assert(source->prev == NULL && source->next == replacement);
    assert(replacement->parent == root && replacement->prev == source);
    assert(replacement->next == after && after->prev == replacement);
    assert(root->last == after && after->next == NULL);
    assert(old->parent == NULL && old->prev == NULL && old->next == NULL);
    xmlFreeNode(old);
    assert(xmlNodeSetContent(replacement, BAD_CAST "moved") == 0);
    bytes = NULL;
    size = 0;
    xmlDocDumpMemoryEnc(doc, &bytes, &size, "UTF-8");
    assert(bytes != NULL && strstr((const char *)bytes, "<move>moved</move>") != NULL);
    assert(strstr((const char *)bytes, "<source/>") != NULL);
    xmlFree(bytes);
    xmlFreeDoc(doc);

    doc = xmlReadMemory("<r><before/><old/><after/></r>",
                        (int)strlen("<r><before/><old/><after/></r>"),
                        NULL, NULL, 0);
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    old = root->children->next;
    before = root->children;
    after = root->last;
    assert(xmlReplaceNode(old, NULL) == old);
    assert(root->children == before && before->next == after);
    assert(root->last == after && after->prev == before);
    assert(old->parent == NULL && old->prev == NULL && old->next == NULL);
    xmlFreeNode(old);
    xmlFreeDoc(doc);

    doc = xmlReadMemory("<r><a/><b/></r>",
                        (int)strlen("<r><a/><b/></r>"), NULL, NULL, 0);
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    old = root->children;
    assert(xmlReplaceNode(old, old) == NULL);
    assert(root->children == old && old->parent == root);
    replacement = xmlNewNode(NULL, BAD_CAST "detached");
    assert(replacement != NULL);
    assert(xmlReplaceNode(NULL, replacement) == NULL);
    assert(replacement->parent == NULL);
    xmlFreeNode(replacement);
    replacement = xmlNewNode(NULL, BAD_CAST "other");
    assert(replacement != NULL);
    assert(xmlReplaceNode(replacement, old) == NULL);
    assert(replacement->parent == NULL);
    xmlFreeNode(replacement);
    xmlFreeDoc(doc);

    doc = xmlReadMemory("<r a='value'><child/></r>",
                        (int)strlen("<r a='value'><child/></r>"),
                        NULL, NULL, 0);
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    assert(root->properties != NULL && root->children != NULL);
    old = root->children;
    assert(xmlReplaceNode(old, (xmlNodePtr)root->properties) == old);
    assert(old->parent == root && root->children == old);
    assert(root->properties->parent == root);
    assert(xmlReplaceNode((xmlNodePtr)root->properties, old) ==
           (xmlNodePtr)root->properties);
    assert(root->properties->parent == root && root->children == old);
    xmlFreeDoc(doc);

    doc = xmlReadMemory("<r>left<!--old-->right</r>",
                        (int)strlen("<r>left<!--old-->right</r>"),
                        NULL, NULL, 0);
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    text = root->children;
    comment = text->next;
    right = root->last;
    assert(text->type == XML_TEXT_NODE && comment->type == XML_COMMENT_NODE);
    replacement = xmlNewText(BAD_CAST "middle");
    assert(replacement != NULL);
    assert(xmlReplaceNode(comment, replacement) == comment);
    assert(root->children == text && root->last == right);
    assert(text->next == replacement && replacement->prev == text);
    assert(replacement->next == right && right->prev == replacement);
    assert(text != replacement && replacement != right);
    assert(comment->parent == NULL && comment->prev == NULL && comment->next == NULL);
    xmlFreeNode(comment);
    xmlFreeDoc(doc);

    doc = xmlReadMemory("<old><child/></old>",
                        (int)strlen("<old><child/></old>"), NULL, NULL, 0);
    assert(doc != NULL);
    old = xmlDocGetRootElement(doc);
    replacement = xmlNewNode(NULL, BAD_CAST "new");
    assert(replacement != NULL);
    assert(xmlReplaceNode(old, replacement) == old);
    assert(xmlDocGetRootElement(doc) == replacement);
    assert(old->parent == NULL && old->prev == NULL && old->next == NULL);
    xmlFreeNode(old);
    assert(xmlNodeSetContent(replacement, BAD_CAST "updated") == 0);
    bytes = NULL;
    size = 0;
    xmlDocDumpMemoryEnc(doc, &bytes, &size, "UTF-8");
    assert(bytes != NULL && strstr((const char *)bytes, "<new>updated</new>") != NULL);
    xmlFree(bytes);
    xmlFreeDoc(doc);

    doc = xmlReadMemory("<old><desc><leaf/></desc></old>",
                        (int)strlen("<old><desc><leaf/></desc></old>"),
                        NULL, NULL, 0);
    assert(doc != NULL);
    old = xmlDocGetRootElement(doc);
    replacement = old->children;
    assert(replacement != NULL);
    assert(xmlReplaceNode(old, replacement) == old);
    assert(xmlDocGetRootElement(doc) == replacement);
    assert(replacement->parent == (xmlNodePtr)doc);
    assert(old->parent == NULL && old->prev == NULL && old->next == NULL);
    xmlFreeNode(old);
    xmlFreeDoc(doc);

    doc = xmlReadMemory("<r><old/></r>",
                        (int)strlen("<r><old/></r>"), NULL, NULL, 0);
    assert(doc != NULL);
    old = xmlDocGetRootElement(doc)->children;
    replacement = xmlNewNode(NULL, BAD_CAST "new");
    assert(replacement != NULL);
    assert(xmlReplaceNode(old, replacement) == old);
#ifndef XML3_REFERENCE_TEST
    xmlFreeDoc(doc);
    assert(old->parent == NULL && old->prev == NULL && old->next == NULL);
    assert(xmlNodeSetContent(old, BAD_CAST "after-doc") == 0);
    assert_text(old, "after-doc");
    xmlFreeNode(old);
#else
    xmlFreeNode(old);
    xmlFreeDoc(doc);
#endif
}

#ifndef XML3_REFERENCE_TEST
static void test_replace_node_rejections(void) {
    xmlDocPtr doc = xmlReadMemory("<r a='one' b='two'><inside/><after/></r>",
                                  (int)strlen("<r a='one' b='two'><inside/><after/></r>"),
                                  NULL, NULL, 0);
    xmlDocPtr other = xmlReadMemory("<other><foreign/></other>", 25, NULL, NULL, 0);
    xmlNodePtr root;
    xmlNodePtr inside;
    xmlNodePtr after;
    xmlNodePtr foreign;
    xmlNodePtr comment;
    xmlNodePtr extra;
    xmlAttrPtr first;
    xmlAttrPtr second;
    assert(doc != NULL && other != NULL);
    root = xmlDocGetRootElement(doc);
    first = root->properties;
    second = first->next;
    inside = root->children;
    after = inside->next;
    foreign = xmlDocGetRootElement(other)->children;

    xmlResetLastError();
    assert(xmlReplaceNode((xmlNodePtr)first, (xmlNodePtr)second) == NULL);
    assert(xmlGetLastError() != NULL && xmlGetLastError()->code == 115);
    assert(root->properties == first && first->next == second &&
           second->prev == first);
    xmlResetLastError();
    assert(xmlReplaceNode(inside, foreign) == NULL);
    assert(xmlGetLastError() != NULL && xmlGetLastError()->code == 115);
    assert(root->children == inside && inside->next == after &&
           foreign->parent == xmlDocGetRootElement(other));
    xmlResetLastError();
    assert(xmlReplaceNode(inside, root) == NULL);
    assert(xmlGetLastError() != NULL && xmlGetLastError()->code == 115);
    assert(root->children == inside && inside->next == after);

    comment = xmlNewComment(BAD_CAST "before");
    extra = xmlNewNode(NULL, BAD_CAST "extra");
    assert(comment != NULL && extra != NULL);
    assert(xmlAddPrevSibling(root, comment) == comment);
    xmlResetLastError();
    assert(xmlReplaceNode(comment, extra) == NULL);
    assert(xmlGetLastError() != NULL && xmlGetLastError()->code == 115);
    assert(comment->parent == (xmlNodePtr)doc && comment->next == root);
    assert(xmlDocGetRootElement(doc) == root && extra->parent == NULL);
    xmlFreeNode(extra);
    xmlFreeDoc(other);
    xmlFreeDoc(doc);
    xmlResetLastError();
}

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
    test_node_list_string();
    test_raw_node_list();
    test_free_node_list();
    test_constructors_and_root_replacement();
    test_promote_descendant_to_root();
    test_namespace_lookup_after_move();
    test_text_merge_and_edit_flow();
    test_parsed_unlink_and_reinsert();
    test_add_sibling_flow();
    test_adjacent_sibling_flow();
    test_replace_node_flow();
    test_node_paths();
    test_node_set_name();
#ifndef XML3_REFERENCE_TEST
    test_replace_node_rejections();
    test_node_set_name_rejections();
    test_raw_node_list_rejections();
    test_node_path_rejections();
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
