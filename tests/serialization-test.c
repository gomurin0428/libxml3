#define _GNU_SOURCE
#include <libxml/parser.h>
#include <libxml/tree.h>

#include <assert.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#if !defined(XML3_DEVELOPMENT_TEST) && !defined(XML3_NO_OOM_TEST)
extern void xml3_oom_enable(long index);
extern void xml3_oom_disable(void);
extern int xml3_oom_was_injected(void);
#endif

enum content_api {
    NEW_TEXT, NEW_TEXT_LEN, NEW_DOC_TEXT, NEW_DOC_TEXT_LEN,
    NEW_COMMENT, NEW_DOC_COMMENT, NEW_CDATA, NEW_PI, NEW_DOC_PI, CONTENT_API_COUNT
};

enum container_api {
    CONTAINER_NODE, CONTAINER_DOC, CONTAINER_RAW, CONTAINER_CHILD,
    CONTAINER_TEXT_CHILD, CONTAINER_PROP, CONTAINER_API_COUNT
};

static xmlNodePtr make_string_list(int mode, xmlDocPtr doc,
                                   const xmlChar *value, int length) {
    return mode == 0 ? xmlStringGetNodeList(doc, value)
        : xmlStringLenGetNodeList(doc, value, mode == 1 ? length : -7);
}

static int append_input(int mode, xmlNodePtr node, const xmlChar *value, int length) {
    if (mode == 0) return xmlNodeAddContent(node, value);
    if (mode == 1) return xmlNodeAddContentLen(node, value, length);
    return xmlTextConcat(node, value, mode == 2 ? length : -7);
}

static int set_input(int mode, xmlNodePtr node, const xmlChar *value, int length) {
    return mode == 0 ? xmlNodeSetContent(node, value)
        : xmlNodeSetContentLen(node, value, mode == 1 ? length : -7);
}

static void test_xml_property_input(void) {
    static const char *values[] = {"", "ja&amp;\xc3\xa9"};
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 32);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    for (int update = 0; update < 2; ++update) {
        for (size_t i = 0; i < sizeof(values) / sizeof(values[0]); ++i) {
            size_t bytes = strlen(values[i]) + 1;
            char *input = mapping + page - bytes;
            memcpy(input, values[i], bytes);
            xmlDocPtr doc = xmlNewDoc(NULL);
            xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
            assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
            xmlNodePtr child = xmlNewTextChild(root, NULL, BAD_CAST "c", BAD_CAST "kept");
            assert(child);
            if (update) assert(xmlNodeSetLang(root, BAD_CAST "old") == 0);
            assert(xmlNodeSetLang(root, BAD_CAST input) == 0);
            assert(mprotect(mapping, (size_t)page, PROT_NONE) == 0);
            assert(xmlNodeSetSpacePreserve(root, -7) == 0);
            assert(xmlNodeGetSpacePreserve(child) == 1);
            assert(xmlNodeSetSpacePreserve(child, 0) == 0);
            assert(xmlNodeGetSpacePreserve(child) == 0);
            xmlChar *language = xmlNodeGetLang(child->children);
            assert(language && strcmp((const char *)language, values[i]) == 0);
            xmlChar *output = NULL;
            int length = 0;
            xmlDocDumpMemoryEnc(doc, &output, &length, "UTF-8");
            assert(output && length > 0);
            xmlFreeDoc(doc);
            assert(strcmp((const char *)language, values[i]) == 0);
            xmlFree(language);
            doc = xmlReadMemory((const char *)output, length, NULL, NULL, 0);
            assert(doc);
            child = xmlDocGetRootElement(doc)->children;
            assert(child && xmlNodeGetSpacePreserve(child) == 0);
            language = xmlNodeGetLang(child);
            assert(language && strcmp((const char *)language, values[i]) == 0);
            xmlFree(language);
            assert(xmlNodeSetLang(child, NULL) == 0);
            language = xmlNodeGetLang(child->children);
            assert(language && language[0] == 0);
            xmlFree(language);
            assert(xmlNodeSetLang(child, BAD_CAST "edited") == 0);
            language = xmlNodeGetLang(child->children);
            assert(language && strcmp((const char *)language, "edited") == 0);
            xmlFree(language);
            xmlFree(output);
            xmlFreeDoc(doc);
            assert(mprotect(mapping, (size_t)page, PROT_READ | PROT_WRITE) == 0);
        }
    }
#ifndef XML3_REFERENCE_TEST
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNodePtr text = xmlNewText(BAD_CAST "kept");
    assert(doc && root && text);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    const xmlChar *protected = (const xmlChar *)(mapping + page);
    xmlNodePtr invalid[] = {(xmlNodePtr)protected, (xmlNodePtr)doc, text};
    for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) {
        xmlResetLastError();
        assert(xmlNodeSetLang(invalid[i], protected) == 1);
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        assert(xmlNodeSetSpacePreserve(invalid[i], 0) == 1);
    }
    assert(xmlNodeSetLang(root, BAD_CAST "prefix-ja") == 0);
    xmlAttrPtr original = root->properties;
    xmlNsPtr ns = original->ns;
    assert(xmlNodeSetLang(root, original->children->content + 7) == 0);
    assert(root->properties == original && original->ns == ns);
    assert(strcmp((const char *)original->children->content, "ja") == 0);
    mapping[page - 1] = 0;
    const unsigned char bad[] = {0xff, 1};
    for (size_t i = 0; i < sizeof(bad); ++i) {
        mapping[page - 2] = (char)bad[i];
        assert(xmlNodeSetLang(root, BAD_CAST (mapping + page - 2)) == 0);
        assert(root->properties == original && original->ns == ns);
        assert(original->children->content[0] == bad[i]);
        assert(original->children->content[1] == 0);
        xmlChar *output = NULL;
        int length = 0;
        xmlResetLastError();
        xmlDocDumpMemoryEnc(doc, &output, &length, "UTF-8");
        assert(output == NULL && length == 0 && xmlGetLastError());
        assert(xmlNodeSetLang(root, BAD_CAST "ja") == 0);
        assert(strcmp((const char *)original->children->content, "ja") == 0);
    }
    assert(xmlNodeSetLang(root, NULL) == 0);
    assert(root->properties == original && original->ns == ns);
    xmlChar *language = xmlNodeGetLang(root);
    assert(language && language[0] == 0);
    xmlFree(language);
    xmlFreeNode(text);
    xmlFreeDoc(doc);
    xmlResetLastError();
#endif
    assert(munmap(mapping, (size_t)page * 2) == 0);
}

static void test_set_input(void) {
    static const char value[] = "v&amp;\xc3\xa9";
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 32);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    for (int mode = 0; mode < 3; ++mode) {
        for (int path = 0; path < 3; ++path) {
            size_t bytes = sizeof(value) - (mode == 1 ? 1 : 0);
            char *input = mapping + page - bytes;
            memcpy(input, value, bytes);
            xmlDocPtr doc = xmlNewDoc(NULL);
            xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
            assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
            xmlNodePtr target;
            if (path == 0) {
                target = xmlNewText(BAD_CAST "old");
                assert(target && xmlAddChild(root, target) == target);
            } else if (path == 1) {
                target = root;
                assert(xmlNewTextChild(root, NULL, BAD_CAST "old", BAD_CAST "kept"));
            } else {
                target = (xmlNodePtr)xmlNewProp(root, BAD_CAST "a", BAD_CAST "old");
                assert(target);
            }
            assert(set_input(mode, target, BAD_CAST input, sizeof(value) - 1) == 0);
            assert(mprotect(mapping, (size_t)page, PROT_NONE) == 0);
            const char *expected = path == 0 ? value : "v&\xc3\xa9";
            xmlChar *content = xmlNodeGetContent(target);
            assert(content && strcmp((const char *)content, expected) == 0);
            xmlFree(content);
            xmlChar *output = NULL;
            int length = 0;
            xmlDocDumpMemoryEnc(doc, &output, &length, "UTF-8");
            assert(output && length > 0);
            xmlFreeDoc(doc);
            doc = xmlReadMemory((const char *)output, length, NULL, NULL, 0);
            assert(doc);
            root = xmlDocGetRootElement(doc);
            target = path == 0 ? root->children
                : path == 1 ? root : (xmlNodePtr)root->properties;
            assert(target);
            content = xmlNodeGetContent(target);
            assert(content && strcmp((const char *)content, expected) == 0);
            xmlFree(content);
            assert(xmlNodeSetContent(target, BAD_CAST "edited") == 0);
            content = xmlNodeGetContent(target);
            assert(content && strcmp((const char *)content, "edited") == 0);
            xmlFree(content);
            xmlFree(output);
            xmlFreeDoc(doc);
            assert(mprotect(mapping, (size_t)page, PROT_READ | PROT_WRITE) == 0);
        }
    }
#ifndef XML3_REFERENCE_TEST
    const xmlChar *protected = (const xmlChar *)(mapping + page);
    for (int mode = 0; mode < 3; ++mode) {
        xmlResetLastError();
        assert(set_input(mode, (xmlNodePtr)protected, protected, 1) == 1);
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        xmlNodePtr text = xmlNewText(BAD_CAST "prefix&amp;");
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
        xmlNodePtr old = xmlNewText(BAD_CAST "&amp;");
        assert(text && root && old && xmlAddChild(root, old) == old);
        assert(set_input(mode, text, text->content + 6, 5) == 0);
        assert(strcmp((const char *)text->content, "&amp;") == 0);
        assert(set_input(mode, root, old->content, 5) == 0);
        assert(root->children && root->children == root->last);
        assert(strcmp((const char *)root->children->content, "&") == 0);
        xmlChar *original = text->content;
        xmlResetLastError();
        assert(xmlNodeSetContentLen(text, protected, INT_MAX) == 1);
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        assert(text->content == original && strcmp((const char *)original, "&amp;") == 0);
        assert(xmlNodeSetContentLen(text, NULL, INT_MAX) == 0 && text->content == NULL);
        assert(xmlNodeSetContentLen(text, protected, 0) == 0);
        assert(text->content && text->content[0] == 0);
        assert(xmlNodeSetContentLen(root, protected, 0) == 0);
        assert(root->children == NULL && root->last == NULL);
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        mapping[page - 1] = 0;
        assert(xmlNodeSetContentLen(text, BAD_CAST (mapping + page - 1), 16) == 0);
        assert(text->content && text->content[0] == 0);
        xmlFreeNode(root);
        xmlFreeNode(text);
    }
    xmlResetLastError();
#endif
    assert(munmap(mapping, (size_t)page * 2) == 0);
}

static void test_append_input(void) {
    static const char suffix[] = "&amp;\xc3\xa9";
    static const char expected[] = "old&amp;\xc3\xa9";
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 32);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    for (int mode = 0; mode < 4; ++mode) {
        for (int path = 0; path < (mode < 2 ? 3 : 1); ++path) {
            size_t bytes = sizeof(suffix) - (mode == 1 || mode == 2 ? 1 : 0);
            char *input = mapping + page - bytes;
            memcpy(input, suffix, bytes);
            xmlDocPtr doc = xmlNewDoc(NULL);
            xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
            xmlNodePtr first = xmlNewText(BAD_CAST "old");
            assert(doc && root && first);
            assert(xmlDocSetRootElement(doc, root) == NULL);
            assert(xmlAddChild(root, first) == first);
            xmlNodePtr tail = NULL;
            if (path == 2) {
                tail = xmlNewComment(BAD_CAST "marker");
                assert(tail && xmlAddChild(root, tail) == tail);
            }
            assert(append_input(mode, path == 0 ? first : root,
                (const xmlChar *)input, sizeof(suffix) - 1) == 0);
            assert(mprotect(mapping, (size_t)page, PROT_NONE) == 0);
            if (path == 2) {
                assert(root->last != tail && root->last->prev == tail);
                assert(root->last->type == XML_TEXT_NODE);
            } else {
                assert(root->last == first && root->children == first);
            }
            xmlChar *content = xmlNodeGetContent(root);
            assert(content && strcmp((const char *)content, expected) == 0);
            xmlFree(content);
            xmlChar *output = NULL;
            int length = 0;
            xmlDocDumpMemoryEnc(doc, &output, &length, "UTF-8");
            assert(output && length > 0);
            xmlFreeDoc(doc);
            doc = xmlReadMemory((const char *)output, length, NULL, NULL, 0);
            assert(doc != NULL);
            root = xmlDocGetRootElement(doc);
            assert(xmlNodeAddContent(root, BAD_CAST "!") == 0);
            content = xmlNodeGetContent(root);
            assert(content && strcmp((const char *)content, "old&amp;\xc3\xa9!") == 0);
            xmlFree(content);
            xmlFree(output);
            xmlFreeDoc(doc);
            assert(mprotect(mapping, (size_t)page, PROT_READ | PROT_WRITE) == 0);
        }
    }
#ifndef XML3_REFERENCE_TEST
    const xmlChar *protected = (const xmlChar *)(mapping + page);
    xmlNodePtr empty = xmlNewText(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    assert(empty && root && empty->content == NULL);
    for (int mode = 0; mode < 4; ++mode) {
        xmlResetLastError();
        assert(append_input(mode, (xmlNodePtr)protected, protected, 1)
            == (mode < 2 ? 1 : -1));
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        xmlNodePtr node = xmlNewText(BAD_CAST "abcdef");
        assert(node != NULL);
        assert(append_input(mode, node, node->content + 2, 3) == 0);
        assert(strcmp((const char *)node->content,
            mode == 1 || mode == 2 ? "abcdefcde" : "abcdefcdef") == 0);
        xmlFreeNode(node);
    }
    xmlResetLastError();
    assert(xmlTextConcat(root, protected, 1) == -1);
    const xmlError *error = xmlGetLastError();
    assert(error && error->code == 115);
    assert(xmlTextConcat(NULL, protected, 1) == -1);
    assert(xmlTextConcat(empty, NULL, INT_MAX) == 0 && empty->content == NULL);
    assert(xmlNodeAddContentLen(empty, protected, 0) == 0 && empty->content == NULL);
    assert(xmlNodeAddContentLen(empty, protected, -7) == 0 && empty->content == NULL);
    assert(xmlGetLastError() == error && error->code == 115);
    assert(xmlTextConcat(empty, protected, 0) == 0);
    assert(empty->content && empty->content[0] == 0);
    for (int mode = 1; mode < 3; ++mode) {
        xmlResetLastError();
        assert(append_input(mode, empty, protected, INT_MAX) == (mode == 1 ? 1 : -1));
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        assert(empty->content[0] == 0);
    }
    xmlResetLastError();
    mapping[page - 1] = 0;
    assert(xmlNodeAddContentLen(root, BAD_CAST (mapping + page - 1), 16) == 0);
    assert(root->children && root->children == root->last);
    assert(root->children->content && root->children->content[0] == 0);
    assert(xmlGetLastError() == NULL);
    xmlFreeNode(root);
    xmlFreeNode(empty);
#endif
    assert(munmap(mapping, (size_t)page * 2) == 0);
}

static void test_string_list_input(void) {
    static const char text[] = "a&amp;\xc3\xa9\r\n\t";
    static const char expected[] = "a&\xc3\xa9\r\n\t";
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 32);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    for (int mode = 0; mode < 3; ++mode) {
        size_t bytes = sizeof(text) - (mode == 1 ? 1 : 0);
        char *input = mapping + page - bytes;
        memcpy(input, text, bytes);
        xmlDocPtr doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
        assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
        xmlNodePtr list = make_string_list(mode, mode == 2 ? NULL : doc,
            (const xmlChar *)input, sizeof(text) - 1);
        assert(list && list->type == XML_TEXT_NODE && list->next == NULL);
        assert(list->doc == (mode == 2 ? NULL : doc) && list->parent == NULL);
        assert(mprotect(mapping, (size_t)page, PROT_NONE) == 0);
        assert(strcmp((const char *)list->content, expected) == 0);
        assert(xmlAddChild(root, list) == list);
        xmlChar *output = NULL;
        int length = 0;
        xmlDocDumpMemoryEnc(doc, &output, &length, "UTF-8");
        assert(output && length > 0);
        xmlFreeDoc(doc);
        doc = xmlReadMemory((const char *)output, length, NULL, NULL, 0);
        assert(doc != NULL);
        list = xmlDocGetRootElement(doc)->children;
        assert(list && strcmp((const char *)list->content, expected) == 0);
        xmlNodeAddContent(list, BAD_CAST "!");
        assert(strcmp((const char *)list->content, "a&\xc3\xa9\r\n\t!") == 0);
        xmlFree(output);
        xmlFreeDoc(doc);
        assert(mprotect(mapping, (size_t)page, PROT_READ | PROT_WRITE) == 0);
    }
#ifndef XML3_REFERENCE_TEST
    const xmlChar *protected = (const xmlChar *)(mapping + page);
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
    for (int mode = 0; mode < 3; ++mode) {
        xmlResetLastError();
        assert(make_string_list(mode, (xmlDocPtr)protected, protected, 1) == NULL);
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        xmlResetLastError();
        assert(make_string_list(mode, (xmlDocPtr)root, protected, 1) == NULL);
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    }
    xmlResetLastError();
    assert(xmlStringLenGetNodeList(doc, protected, INT_MAX) == NULL);
    const xmlError *error = xmlGetLastError();
    assert(error && error->code == 115);
    assert(xmlStringGetNodeList((xmlDocPtr)protected, NULL) == NULL);
    assert(xmlStringLenGetNodeList((xmlDocPtr)protected, NULL, INT_MAX) == NULL);
    assert(xmlStringLenGetNodeList((xmlDocPtr)protected, protected, 0) == NULL);
    assert(xmlGetLastError() == error && error->code == 115);
    xmlResetLastError();
    assert(xmlStringGetNodeList((xmlDocPtr)protected, BAD_CAST "") == NULL);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    xmlResetLastError();
    mapping[page - 1] = 0;
    assert(xmlStringLenGetNodeList(doc, BAD_CAST (mapping + page - 1), 16) == NULL);
    assert(xmlStringGetNodeList(doc, BAD_CAST (mapping + page - 1)) == NULL);
    assert(xmlGetLastError() == NULL);
    assert(root->children == NULL && root->last == NULL);
    xmlFreeDoc(doc);
#endif
    assert(munmap(mapping, (size_t)page * 2) == 0);
}

static xmlNodePtr make_container(enum container_api api, xmlDocPtr doc,
                                 xmlNodePtr parent, xmlNsPtr ns,
                                 const xmlChar *name, const xmlChar *value) {
    switch (api) {
    case CONTAINER_NODE: return xmlNewNode(ns, name);
    case CONTAINER_DOC: return xmlNewDocNode(doc, ns, name, value);
    case CONTAINER_RAW: return xmlNewDocRawNode(doc, ns, name, value);
    case CONTAINER_CHILD: return xmlNewChild(parent, ns, name, value);
    case CONTAINER_TEXT_CHILD: return xmlNewTextChild(parent, ns, name, value);
    case CONTAINER_PROP: return (xmlNodePtr)xmlNewDocProp(doc, name, value);
    default: assert(0); return NULL;
    }
}

static void test_container_input(void) {
    static const char name[] = "子";
    static const char text[] = "a&amp;\xc3\xa9";
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 32);
    char *mapping = mmap(NULL, (size_t)page * 4, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    assert(mprotect(mapping + page * 3, (size_t)page, PROT_NONE) == 0);
    for (enum container_api api = CONTAINER_NODE; api < CONTAINER_API_COUNT; ++api) {
        int child_api = api == CONTAINER_CHILD || api == CONTAINER_TEXT_CHILD;
        int raw = api == CONTAINER_RAW || api == CONTAINER_TEXT_CHILD;
        for (int mode = 0; mode < 3; ++mode) {
            char *input_name = mapping + page - sizeof(name);
            const char *value = mode == 2 ? text : "";
            size_t bytes = strlen(value) + 1;
            char *input_value = mapping + page * 3 - bytes;
            memcpy(input_name, name, sizeof(name));
            memcpy(input_value, value, bytes);
            xmlDocPtr doc = xmlNewDoc(NULL);
            xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
            assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
            xmlNsPtr ns = xmlNewNs(root, BAD_CAST "urn:container", BAD_CAST "p");
            assert(ns != NULL);
            xmlSetNs(root, ns);
            xmlNodePtr node = make_container(api, doc, root, child_api ? NULL : ns,
                (const xmlChar *)input_name,
                mode == 0 ? NULL : (const xmlChar *)input_value);
            assert(node && node->name != (const xmlChar *)input_name);
            assert(mprotect(mapping, (size_t)page, PROT_NONE) == 0);
            assert(mprotect(mapping + page * 2, (size_t)page, PROT_NONE) == 0);
            assert(strcmp((const char *)node->name, name) == 0);
            assert(node->ns == (api == CONTAINER_PROP ? NULL : ns));
            assert(node->parent == (child_api ? root : NULL));
            if (mode < 2 || api == CONTAINER_NODE) {
                assert((node->children != NULL) == (raw && mode == 1));
            }
            const char *expected = mode < 2 || api == CONTAINER_NODE
                ? "" : raw ? text : "a&\xc3\xa9";
            xmlChar *content = xmlNodeGetContent(node);
            assert(content && strcmp((const char *)content, expected) == 0);
            xmlFree(content);
            if (!child_api) assert(xmlAddChild(root, node) == node);
            xmlChar *output = NULL;
            int length = 0;
            xmlDocDumpMemoryEnc(doc, &output, &length, "UTF-8");
            assert(output && length > 0);
            xmlFreeDoc(doc);
            doc = xmlReadMemory((const char *)output, length, NULL, NULL, 0);
            assert(doc != NULL);
            root = xmlDocGetRootElement(doc);
            node = api == CONTAINER_PROP ? (xmlNodePtr)root->properties : root->children;
            assert(node && strcmp((const char *)node->name, name) == 0);
            content = xmlNodeGetContent(node);
            assert(content && strcmp((const char *)content, expected) == 0);
            xmlFree(content);
            xmlNodeSetContent(node, BAD_CAST "edited&amp;value");
            content = xmlNodeGetContent(node);
            assert(content && strcmp((const char *)content, "edited&value") == 0);
            assert(strcmp((const char *)node->name, name) == 0);
            xmlFree(content);
            xmlFree(output);
            xmlFreeDoc(doc);
            assert(mprotect(mapping, (size_t)page, PROT_READ | PROT_WRITE) == 0);
            assert(mprotect(mapping + page * 2, (size_t)page, PROT_READ | PROT_WRITE) == 0);
        }
    }
#ifndef XML3_REFERENCE_TEST
    const xmlChar *protected = (const xmlChar *)(mapping + page);
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
    xmlNsPtr ns = xmlNewNs(root, BAD_CAST "urn:container", BAD_CAST "p");
    assert(ns != NULL);
    for (enum container_api api = CONTAINER_NODE; api < CONTAINER_API_COUNT; ++api) {
        xmlResetLastError();
        assert(make_container(api, (xmlDocPtr)protected, (xmlNodePtr)protected,
            (xmlNsPtr)protected, protected, protected) == NULL);
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        if (api != CONTAINER_PROP) {
            xmlResetLastError();
            assert(make_container(api, doc, root, (xmlNsPtr)protected,
                protected, protected) == NULL);
            assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        }
        xmlResetLastError();
        assert(make_container(api, (xmlDocPtr)protected, (xmlNodePtr)protected,
            (xmlNsPtr)protected, NULL, protected) == NULL);
        if (api == CONTAINER_CHILD || api == CONTAINER_TEXT_CHILD)
            assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        else
            assert(xmlGetLastError() == NULL);
    }
    assert(xmlNewDocNode(doc, ns, BAD_CAST "n", BAD_CAST "&missing;") == NULL);
    assert(xmlNewChild(root, NULL, BAD_CAST "n", BAD_CAST "&missing;") == NULL);
    assert(xmlNewDocProp(doc, BAD_CAST "p:n", BAD_CAST "value") == NULL);
    assert(root->children == NULL && root->properties == NULL && root->nsDef == ns);
    xmlResetLastError();
    xmlFreeDoc(doc);
#endif
    assert(munmap(mapping, (size_t)page * 4) == 0);
}

static int bounded_content(enum content_api api) {
    return api == NEW_TEXT_LEN || api == NEW_DOC_TEXT_LEN || api == NEW_CDATA;
}

static int affiliated_content(enum content_api api) {
    return api == NEW_DOC_TEXT || api == NEW_DOC_TEXT_LEN ||
           api == NEW_DOC_COMMENT || api == NEW_CDATA || api == NEW_DOC_PI;
}

static xmlNodePtr make_content(enum content_api api, xmlDocPtr doc,
                               const xmlChar *content, int length) {
    switch (api) {
    case NEW_TEXT: return xmlNewText(content);
    case NEW_TEXT_LEN: return xmlNewTextLen(content, length);
    case NEW_DOC_TEXT: return xmlNewDocText(doc, content);
    case NEW_DOC_TEXT_LEN: return xmlNewDocTextLen(doc, content, length);
    case NEW_COMMENT: return xmlNewComment(content);
    case NEW_DOC_COMMENT: return xmlNewDocComment(doc, content);
    case NEW_CDATA: return xmlNewCDataBlock(doc, content, length);
    case NEW_PI: return xmlNewPI(BAD_CAST "p", content);
    case NEW_DOC_PI: return xmlNewDocPI(doc, BAD_CAST "p", content);
    default: assert(0); return NULL;
    }
}

static void test_content_input(void) {
    static const char text[] = "A&\xc3\xa9";
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 32);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    for (enum content_api api = NEW_TEXT; api < CONTENT_API_COUNT; ++api) {
        size_t bytes = sizeof(text) - (bounded_content(api) ? 1 : 0);
        char *input = mapping + page - bytes;
        memcpy(input, text, bytes);
        xmlDocPtr doc = xmlNewDoc(NULL);
        assert(doc != NULL);
        xmlNodePtr node = make_content(api, doc, (const xmlChar *)input, sizeof(text) - 1);
        assert(node && node->content != (const xmlChar *)input);
        if (affiliated_content(api)) assert(node->doc == doc);
        assert(mprotect(mapping, (size_t)page, PROT_NONE) == 0);
        assert(node->content && strcmp((const char *)node->content, text) == 0);
        xmlElementType type = node->type;
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
        assert(root && xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, node) == node);
        xmlChar *output = NULL;
        int size = 0;
        xmlDocDumpMemoryEnc(doc, &output, &size, "UTF-8");
        assert(output && size > 0);
        xmlFreeDoc(doc);
        doc = xmlReadMemory((const char *)output, size, NULL, NULL, 0);
        assert(doc != NULL);
        node = xmlDocGetRootElement(doc)->children;
        assert(node && node->type == type && node->content);
        assert(strcmp((const char *)node->content, text) == 0);
        xmlFree(output);
        xmlFreeDoc(doc);
        assert(mprotect(mapping, (size_t)page, PROT_READ | PROT_WRITE) == 0);

        doc = xmlNewDoc(NULL);
        assert(doc != NULL);
        node = make_content(api, doc, NULL, 0);
        assert(node && node->content == NULL);
        xmlFreeNode(node);
        input = mapping + page - 1;
        *input = '\0';
        node = make_content(api, doc, (const xmlChar *)input, 1);
        assert(node && node->content && node->content[0] == 0);
        xmlFreeNode(node);
#ifndef XML3_REFERENCE_TEST
        const xmlChar *protected = (const xmlChar *)(mapping + page);
        if (affiliated_content(api)) {
            assert(make_content(api, (xmlDocPtr)(mapping + page), protected, 1) == NULL);
            assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        }
        if (bounded_content(api)) {
            node = make_content(api, doc, protected, 0);
            assert(node && node->content && node->content[0] == 0);
            xmlFreeNode(node);
            assert(make_content(api, doc, protected, -1) == NULL);
            assert(make_content(api, doc, (const xmlChar *)input, INT_MAX) == NULL);
            assert(xmlGetLastError() && xmlGetLastError()->code == 115);
            node = make_content(api, doc, (const xmlChar *)input, 32);
            assert(node && node->content && node->content[0] == 0);
            xmlFreeNode(node);
            node = make_content(api, doc, NULL, INT_MIN);
            assert(node && node->content == NULL);
            xmlFreeNode(node);
        }
        xmlResetLastError();
#endif
        xmlFreeDoc(doc);
    }
    assert(munmap(mapping, (size_t)page * 2) == 0);
}

static void test_pi_target_input(void) {
    static const char *names[] = {"p", "処理", "", "bad name", "xml", "\xff"};
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 32);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    for (int affiliated = 0; affiliated <= 1; ++affiliated) {
        for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
            size_t size = strlen(names[i]) + 1;
            char *input = mapping + page - size;
            memcpy(input, names[i], size);
            xmlDocPtr doc = xmlNewDoc(NULL);
            assert(doc != NULL);
            xmlNodePtr pi = affiliated
                ? xmlNewDocPI(doc, (const xmlChar *)input, (const xmlChar *)input)
                : xmlNewPI((const xmlChar *)input, (const xmlChar *)input);
            assert(pi && pi->name != (const xmlChar *)input);
            assert(mprotect(mapping, (size_t)page, PROT_NONE) == 0);
            assert(pi->name && pi->content);
            assert(memcmp(pi->name, names[i], size) == 0);
            assert(memcmp(pi->content, names[i], size) == 0);
            xmlNodeSetContent(pi, BAD_CAST "edited");
            assert(strcmp((const char *)pi->name, names[i]) == 0);
            assert(strcmp((const char *)pi->content, "edited") == 0);
            if (i < 2) {
                xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
                assert(root && xmlDocSetRootElement(doc, root) == NULL);
                assert(xmlAddChild(root, pi) == pi);
                xmlChar *output = NULL;
                int length = 0;
                xmlDocDumpMemoryEnc(doc, &output, &length, "UTF-8");
                assert(output && length > 0);
                xmlFreeDoc(doc);
                doc = xmlReadMemory((const char *)output, length, NULL, NULL, 0);
                assert(doc != NULL);
                pi = xmlDocGetRootElement(doc)->children;
                assert(pi && pi->type == XML_PI_NODE);
                assert(strcmp((const char *)pi->name, names[i]) == 0);
                assert(strcmp((const char *)pi->content, "edited") == 0);
                xmlFree(output);
            } else {
                xmlFreeNode(pi);
            }
            xmlFreeDoc(doc);
            assert(mprotect(mapping, (size_t)page, PROT_READ | PROT_WRITE) == 0);
        }
    }
#ifndef XML3_REFERENCE_TEST
    const xmlChar *protected = (const xmlChar *)(mapping + page);
    xmlResetLastError();
    assert(xmlNewDocPI((xmlDocPtr)protected, protected, protected) == NULL);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    assert(xmlNewDocPI((xmlDocPtr)protected, NULL, protected) == NULL);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    assert(xmlNewPI(NULL, protected) == NULL);
    assert(xmlGetLastError() && xmlGetLastError()->code == 115);
    xmlResetLastError();
#endif
    assert(munmap(mapping, (size_t)page * 2) == 0);
}

static void test_document_version_input(void) {
    static const char *versions[] = {NULL, "", "1.0", "1.1", "odd version", "\xff"};
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 32);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    for (size_t i = 0; i < sizeof(versions) / sizeof(versions[0]); ++i) {
        const char *expected = versions[i] ? versions[i] : "1.0";
        size_t length = strlen(expected);
        char *input = NULL;
        if (versions[i]) {
            input = mapping + page - length - 1;
            memcpy(input, expected, length + 1);
        }
        xmlDocPtr doc = xmlNewDoc((const xmlChar *)input);
        assert(doc != NULL && doc->version != (const xmlChar *)input);
        assert(mprotect(mapping, (size_t)page, PROT_NONE) == 0);
        assert(doc->version && memcmp(doc->version, expected, length + 1) == 0);
        if (strcmp(expected, "1.0") == 0) {
            xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
            assert(root && xmlDocSetRootElement(doc, root) == NULL);
            assert(xmlNewTextChild(root, NULL, BAD_CAST "x", BAD_CAST "A&\xc3\xa9"));
            xmlChar *output = NULL;
            int size = 0;
            xmlDocDumpMemoryEnc(doc, &output, &size, "UTF-8");
            assert(output && size > 0);
            xmlFreeDoc(doc);
            doc = xmlReadMemory((const char *)output, size, NULL, NULL, 0);
            assert(doc != NULL);
            xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
            assert(content && strcmp((const char *)content, "A&\xc3\xa9") == 0);
            xmlFree(content);
            xmlFree(output);
        }
        xmlFreeDoc(doc);
        assert(mprotect(mapping, (size_t)page, PROT_READ | PROT_WRITE) == 0);
    }
    assert(munmap(mapping, (size_t)page * 2) == 0);
}

static void expect_exact_output(const char *input, const char *expected) {
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlChar *memory = NULL;
    int size = 0;

    assert(doc != NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && size == (int)strlen(expected));
    assert(memcmp(memory, expected, (size_t)size) == 0);
    xmlFree(memory);
    xmlFreeDoc(doc);
}

static void expect_default_output(const char *input, const char *expected) {
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlChar *memory = NULL, *encoded = NULL;
    int size = 0, encoded_size = 0;
    assert(doc);
    xmlChar *original_content = xmlNodeGetContent(xmlDocGetRootElement(doc));
    assert(original_content);
    xmlDocDumpMemory(doc, &memory, &size);
    xmlDocDumpMemoryEnc(doc, &encoded, &encoded_size, NULL);
    assert(memory && encoded && size == (int)strlen(expected));
    assert(encoded_size == size && memory[size] == 0 && encoded[size] == 0);
    assert(memcmp(memory, expected, (size_t)size) == 0);
    assert(memcmp(memory, encoded, (size_t)size) == 0);
    xmlFree(encoded);
    xmlFreeDoc(doc);
    doc = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(doc && xmlDocGetRootElement(doc));
    xmlChar *content = xmlNodeGetContent(xmlDocGetRootElement(doc));
    assert(content && strcmp((const char *)content,
                             (const char *)original_content) == 0);
    xmlFree(content);
    xmlFree(original_content);
    xmlFree(memory);
    xmlFreeDoc(doc);
}

static void test_default_serialization(void) {
    expect_default_output("<r a='&amp;'>x</r>",
        "<?xml version=\"1.0\"?>\n<r a=\"&amp;\">x</r>\n");
    expect_default_output(
        "<名 xmlns:p='urn:é' p:a='é'>&amp;é😀<![CDATA[名]]><!--名--><?work 名?></名>",
        "<?xml version=\"1.0\"?>\n"
        "<名 xmlns:p=\"urn:&#xE9;\" p:a=\"&#xE9;\">"
        "&amp;&#xE9;&#x1F600;<![CDATA[名]]><!--名--><?work 名?></名>\n");
    expect_default_output("<r>\xc2\x80\xdf\xbf\xe0\xa0\x80\xef\xbf\xbd"
                          "\xf0\x90\x80\x80\xf4\x8f\xbf\xbf</r>",
        "<?xml version=\"1.0\"?>\n<r>"
        "&#x80;&#x7FF;&#x800;&#xFFFD;&#x10000;&#x10FFFF;</r>\n");
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlChar *memory = NULL;
    int size = 0;
    const char *empty = "<?xml version=\"1.0\"?>\n";
#ifndef XML3_REFERENCE_TEST
    /* A pointer that is not a registered document is refused before its
     * memory (or its encoding) is read (libxml2 reads it). */
    {
        xmlChar *bogus_memory = (xmlChar *)1;
        int bogus_size = 99;

        xmlResetLastError();
        xmlDocDumpMemory((xmlDocPtr)(uintptr_t)8, &bogus_memory, &bogus_size);
        assert(bogus_memory == NULL && bogus_size == 0 && xmlGetLastError());
        xmlResetLastError();
        xmlDocDumpFormatMemoryEnc((xmlDocPtr)(uintptr_t)8, &bogus_memory,
                                  &bogus_size, NULL, 1);
        assert(bogus_memory == NULL && bogus_size == 0);
        xmlResetLastError();
    }
#endif
    assert(doc);
    xmlDocDumpMemory(doc, &memory, &size);
    assert(memory && size == (int)strlen(empty));
    assert(strcmp((const char *)memory, empty) == 0);
    xmlFree(memory);
    xmlFreeDoc(doc);
}

static void expect_formatted_output(const char *input, const char *expected,
                                    const char *encoding, int format) {
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlChar *memory = NULL, *before = NULL, *after = NULL;
    int size = 0, before_size = 0, after_size = 0;
    assert(doc);
    xmlDocDumpMemoryEnc(doc, &before, &before_size, encoding);
    assert(before);
    xmlDocDumpFormatMemoryEnc(doc, &memory, &size, encoding, format);
    assert(memory && size == (int)strlen(expected) && memory[size] == 0);
    assert(memcmp(memory, expected, (size_t)size) == 0);
    if (encoding == NULL) {
        xmlChar *wrapped = NULL;
        int wrapped_size = 0;
        xmlDocDumpFormatMemory(doc, &wrapped, &wrapped_size, format);
        assert(wrapped && wrapped_size == size);
        assert(memcmp(wrapped, memory, (size_t)size + 1) == 0);
        xmlFree(wrapped);
    }
    xmlDocDumpMemoryEnc(doc, &after, &after_size, encoding);
    assert(after && after_size == before_size);
    assert(memcmp(before, after, (size_t)before_size + 1) == 0);
    xmlFree(before);
    xmlFree(after);
    xmlFreeDoc(doc);
    doc = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(doc && xmlDocGetRootElement(doc));
    xmlFree(memory);
    xmlFreeDoc(doc);
}

static void test_formatted_serialization(void) {
    expect_formatted_output("<!--before--><r><a/><b><c/></b><!--n--><?p d?></r><?after?>",
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<!--before-->\n<r>\n  <a/>\n  <b>\n    <c/>\n  </b>\n"
        "  <!--n-->\n  <?p d?>\n</r>\n<?after?>\n", "UTF-8", 1);
    expect_formatted_output("<r>before<a><b/></a>after<![CDATA[x]]></r>",
        "<?xml version=\"1.0\"?>\n"
        "<r>before<a><b/></a>after<![CDATA[x]]></r>\n", NULL, 1);
    expect_formatted_output("<r><![CDATA[x]]><a><b/></a></r>",
        "<?xml version=\"1.0\"?>\n<r><![CDATA[x]]><a><b/></a></r>\n", NULL, 1);
    expect_formatted_output("<r> <a><b/></a></r>",
        "<?xml version=\"1.0\"?>\n<r> <a><b/></a></r>\n", NULL, 1);
    expect_formatted_output("<r><a>x<b><c/></b></a><d><e/></d></r>",
        "<?xml version=\"1.0\"?>\n"
        "<r>\n  <a>x<b><c/></b></a>\n  <d>\n    <e/>\n  </d>\n</r>\n", NULL, -1);
    expect_formatted_output("<名 xmlns:p='urn:é'><p:x a='é'>😀</p:x></名>",
        "<?xml version=\"1.0\"?>\n<名 xmlns:p=\"urn:&#xE9;\">\n"
        "  <p:x a=\"&#xE9;\">&#x1F600;</p:x>\n</名>\n", NULL, 2);
    expect_formatted_output("<r><a/><b><c/></b></r>",
        "<?xml version=\"1.0\"?>\n<r><a/><b><c/></b></r>\n", NULL, 0);
    expect_formatted_output("<r><a/><b><c/></b></r>",
        "<?xml version=\"1.0\" encoding=\"uTf-8\"?>\n"
        "<r><a/><b><c/></b></r>\n", "uTf-8", 0);

    char input[512] = "", expected[8192] = "<?xml version=\"1.0\"?>\n";
    for (int depth = 0; depth < 35; ++depth) {
        strcat(input, "<n>");
        for (int i = 0; i < depth && i < 30; ++i) strcat(expected, "  ");
        strcat(expected, "<n>\n");
    }
    strcat(input, "<leaf/>");
    for (int i = 0; i < 30; ++i) strcat(expected, "  ");
    strcat(expected, "<leaf/>\n");
    for (int depth = 34; depth >= 0; --depth) {
        strcat(input, "</n>");
        for (int i = 0; i < depth && i < 30; ++i) strcat(expected, "  ");
        strcat(expected, "</n>\n");
    }
    expect_formatted_output(input, expected, NULL, 1);
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlChar *memory = NULL;
    int size = 0;
    assert(doc);
    xmlDocDumpFormatMemory(doc, &memory, &size, 1);
    assert(memory && strcmp((const char *)memory, "<?xml version=\"1.0\"?>\n") == 0);
    xmlFree(memory);
    xmlFreeDoc(doc);
}

static void assert_parsed_pi_content(xmlDocPtr doc) {
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(root && doc->children->type == XML_PI_NODE);
    assert(doc->children->content == NULL && root->next->content == NULL);
    xmlNodePtr absent = root->children;
    xmlNodePtr empty = absent->next;
    xmlNodePtr blanks = empty->next;
    xmlNodePtr data = blanks->next;
    xmlNodePtr unicode = data->next;
    assert(absent->type == XML_PI_NODE && absent->content == NULL);
    assert(empty->type == XML_PI_NODE && empty->content && empty->content[0] == 0);
    assert(blanks->type == XML_PI_NODE && blanks->content && blanks->content[0] == 0);
    assert(data->type == XML_PI_NODE && xmlStrEqual(data->content, BAD_CAST "é&amp;  "));
    assert(unicode->type == XML_PI_NODE && xmlStrEqual(unicode->name, BAD_CAST "名"));
    assert(unicode->content == NULL && unicode->next == NULL);
    xmlChar *content = xmlNodeGetContent(absent);
    assert(content && content[0] == 0);
    xmlFree(content);
}

static void test_parsed_pi_content(void) {
    char input[] = "<?before?><r><?absent?><?empty ?><?blanks \t\r\n?>"
                   "<?data é&amp;  ?><?名?></r><?after?>";
    const char *expected = "<?xml version=\"1.0\"?>\n<?before?>\n"
        "<r><?absent?><?empty ?><?blanks ?><?data é&amp;  ?><?名?></r>\n<?after?>\n";
    const char *formatted = "<?xml version=\"1.0\"?>\n<?before?>\n<r>\n"
        "  <?absent?>\n  <?empty ?>\n  <?blanks ?>\n  <?data é&amp;  ?>\n"
        "  <?名?>\n</r>\n<?after?>\n";
    xmlDocPtr doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
    xmlChar *memory = NULL, *pretty = NULL;
    int size = 0, pretty_size = 0;
    assert(doc);
    memset(input, 'x', sizeof(input) - 1);
    assert_parsed_pi_content(doc);
    xmlDocDumpMemory(doc, &memory, &size);
    assert(memory && size == (int)strlen(expected));
    assert(strcmp((const char *)memory, expected) == 0);
    xmlDocDumpFormatMemory(doc, &pretty, &pretty_size, 1);
    assert(pretty && pretty_size == (int)strlen(formatted));
    assert(strcmp((const char *)pretty, formatted) == 0);
    assert_parsed_pi_content(doc);
    xmlFree(pretty);
    xmlFreeDoc(doc);
    doc = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    xmlFree(memory);
    assert(doc);
    assert_parsed_pi_content(doc);
    xmlNodePtr absent = xmlDocGetRootElement(doc)->children;
    xmlNodeSetContent(absent, BAD_CAST "");
    assert(absent->content && absent->content[0] == 0);
    xmlNodeSetContent(absent, NULL);
    assert(absent->content == NULL);
    xmlDocDumpMemory(doc, &memory, &size);
    assert(memory && size == (int)strlen(expected));
    assert(strcmp((const char *)memory, expected) == 0);
    xmlFree(memory);
    xmlFreeDoc(doc);
}

static void test_shared_lexical_cases(void) {
    static const char simple_input[] = "<r a='&amp;'>x</r>";
    static const char simple_expected[] =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<r a=\"&amp;\">x</r>\n";
    static const char representative_input[] =
        "<名 xmlns='urn:default' xmlns:p='urn:p' "
        "p:属性='a&amp;&quot;&#9;&#10;'>é&amp;&lt;"
        "<![CDATA[c]]><!--inside--><?pi data?></名>";
    static const char representative_expected[] =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<名 xmlns=\"urn:default\" xmlns:p=\"urn:p\" "
        "p:属性=\"a&amp;&quot;&#9;&#10;\">é&amp;&lt;"
        "<![CDATA[c]]><!--inside--><?pi data?></名>\n";

    expect_exact_output(simple_input, simple_expected);
    expect_exact_output(representative_input, representative_expected);
}

static void test_cdata_construction(void) {
    static const char expected[] =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<r><![CDATA[A&<]]]]><![CDATA[>B]]><![CDATA[x]]>"
        "<![CDATA[]]><![CDATA[]]></r>\n";
    xmlChar raw[] = {'A', '&', '<', ']', ']', '>', 'B'};
    static const xmlChar embedded[] = {'x', 0, 'h'};
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNodePtr node = xmlNewCDataBlock(doc, raw, sizeof(raw));
    xmlNodePtr other = xmlNewCDataBlock(NULL, embedded, sizeof(embedded));
    xmlNodePtr absent = xmlNewCDataBlock(doc, NULL, -1);
    xmlNodePtr empty = xmlNewCDataBlock(doc, BAD_CAST "", 0);
    xmlDocPtr reparsed;
    xmlChar *memory = NULL, *content;
    int size = 0;
    assert(doc && root && node && other && absent && empty);
    assert(node->type == XML_CDATA_SECTION_NODE && node->name == NULL);
    assert(node->doc == doc && node->parent == NULL && doc->children == NULL);
    assert(other->doc == NULL && other->name == NULL);
    assert(absent->content == NULL && empty->content && !empty->content[0]);
    assert(xmlNewCDataBlock(doc, BAD_CAST "x", -1) == NULL);
#ifndef XML3_REFERENCE_TEST
    assert(xmlNewCDataBlock((xmlDocPtr)root, BAD_CAST "x", 1) == NULL);
#endif
    raw[0] = 'Z';
    assert(strcmp((const char *)node->content, "A&<]]>B") == 0);
    assert(strcmp((const char *)other->content, "x") == 0);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlAddChild(root, node) == node);
    assert(xmlAddChild(root, other) == other);
    assert(node->next == other && other->doc == doc);
    assert(xmlAddChild(root, absent) == absent);
    assert(xmlAddChild(root, empty) == empty);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory && size == (int)strlen(expected));
    assert(memcmp(memory, expected, (size_t)size) == 0);
    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed);
    content = xmlNodeGetContent(xmlDocGetRootElement(reparsed));
    assert(content && strcmp((const char *)content, "A&<]]>Bx") == 0);
    xmlFree(content);
    xmlFreeDoc(reparsed);
    xmlFree(memory);
#ifndef XML3_REFERENCE_TEST
    assert(xmlNodeSetContent(node, BAD_CAST "\xc3") == 0);
    memory = NULL;
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory == NULL && size == 0);
    assert(xmlNodeSetContent(node, BAD_CAST "fixed") == 0);
    xmlUnlinkNode(node);
    xmlFreeDoc(doc);
    assert(node->doc == doc && node->name == NULL);
    assert(xmlNodeAddContent(node, BAD_CAST "!") == 0);
    assert(strcmp((const char *)node->content, "fixed!") == 0);
    xmlFreeNode(node);
#else
    xmlFreeDoc(doc);
#endif
}

static void test_constructed_comments_and_pi(int affiliated) {
    static const char expected[] =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<!--before-->\n"
        "<r><!--note--><?work 値?><!----><?empty ?><?bare?>"
        "<?xml-stylesheet type='x'?></r>\n<?after?>\n";
    char comment_content[] = "note";
    char target[] = "work";
    char pi_content[] = "値";
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNodePtr comment = affiliated
        ? xmlNewDocComment(doc, BAD_CAST comment_content)
        : xmlNewComment(BAD_CAST comment_content);
    xmlNodePtr pi = affiliated
        ? xmlNewDocPI(doc, BAD_CAST target, BAD_CAST pi_content)
        : xmlNewPI(BAD_CAST target, BAD_CAST pi_content);
    xmlNodePtr null_comment = affiliated
        ? xmlNewDocComment(doc, NULL) : xmlNewComment(NULL);
    xmlNodePtr empty_comment = affiliated
        ? xmlNewDocComment(doc, BAD_CAST "") : xmlNewComment(BAD_CAST "");
    xmlChar *memory = NULL;
    int size = 0;

    assert(doc && root && comment && pi && null_comment && empty_comment);
    assert(comment->type == XML_COMMENT_NODE && pi->type == XML_PI_NODE);
    assert(comment->parent == NULL && comment->doc == (affiliated ? doc : NULL));
    assert(pi->parent == NULL && pi->doc == (affiliated ? doc : NULL));
    assert(pi->ns == NULL && doc->children == NULL && doc->last == NULL);
    assert(strcmp((const char *)comment->name, "comment") == 0);
    assert(null_comment->content == NULL);
    assert(empty_comment->content && empty_comment->content[0] == 0);
    assert(xmlNewPI(NULL, BAD_CAST "data") == NULL);
    assert(xmlNewDocPI(doc, NULL, BAD_CAST "data") == NULL);
#ifndef XML3_REFERENCE_TEST
    assert(xmlNewDocComment((xmlDocPtr)root, BAD_CAST "bad") == NULL);
    assert(xmlNewDocPI((xmlDocPtr)root, BAD_CAST "bad", NULL) == NULL);
#endif
    comment_content[0] = 'X';
    target[0] = 'X';
    pi_content[0] = 'X';
    assert(xmlAddChild((xmlNodePtr)doc, xmlNewComment(BAD_CAST "before")));
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlAddChild(root, comment) == comment);
    assert(xmlAddChild(root, pi) == pi);
    assert(xmlAddChild(root, null_comment) == null_comment);
    assert(xmlAddChild(root, empty_comment) == empty_comment);
    assert(xmlAddChild(root, affiliated
        ? xmlNewDocPI(doc, BAD_CAST "empty", BAD_CAST "")
        : xmlNewPI(BAD_CAST "empty", BAD_CAST "")));
    assert(xmlAddChild(root, affiliated
        ? xmlNewDocPI(doc, BAD_CAST "bare", NULL)
        : xmlNewPI(BAD_CAST "bare", NULL)));
    assert(xmlAddChild(root, xmlNewPI(BAD_CAST "xml-stylesheet", BAD_CAST "type='x'")));
    assert(xmlAddChild((xmlNodePtr)doc, xmlNewPI(BAD_CAST "after", NULL)));
    assert(comment->doc == doc && pi->doc == doc);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory && size == (int)sizeof(expected) - 1);
    assert(memcmp(memory, expected, sizeof(expected)) == 0);
    xmlFreeDoc(doc);
    doc = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(doc);
    root = xmlDocGetRootElement(doc);
    comment = root->children;
    pi = comment->next;
    assert(comment->type == XML_COMMENT_NODE);
    assert(strcmp((const char *)comment->content, "note") == 0);
    assert(pi->type == XML_PI_NODE && strcmp((const char *)pi->name, "work") == 0);
    assert(strcmp((const char *)pi->content, "値") == 0);
    xmlUnlinkNode(pi);
    assert(pi->parent == NULL && pi->next == NULL && pi->prev == NULL);
    xmlFreeNode(pi);
    xmlFreeDoc(doc);
    xmlFree(memory);
}

static void test_document_misc_lifetime(void) {
    xmlNodePtr comment = xmlNewDocComment(NULL, BAD_CAST "note");
    xmlNodePtr pi = xmlNewDocPI(NULL, BAD_CAST "work", NULL);
    assert(comment && pi && comment->doc == NULL && pi->doc == NULL);
    assert(strcmp((const char *)comment->content, "note") == 0);
    assert(strcmp((const char *)pi->name, "work") == 0 && pi->content == NULL);
    xmlFreeNode(comment);
    xmlFreeNode(pi);
#ifndef XML3_REFERENCE_TEST
    {
        xmlDocPtr doc = xmlNewDoc(NULL);
        assert(doc);
        comment = xmlNewDocComment(doc, BAD_CAST "retained");
        pi = xmlNewDocPI(doc, BAD_CAST "target", BAD_CAST "data");
        assert(comment && pi && doc->children == NULL);
        xmlFreeDoc(doc);
        assert(comment->doc == doc && pi->doc == doc);
        assert(xmlNodeSetContent(comment, BAD_CAST "fixed") == 0);
        assert(xmlNodeAddContent(pi, BAD_CAST "!") == 0);
        assert(strcmp((const char *)comment->content, "fixed") == 0);
        xmlFreeNode(comment);
        assert(strcmp((const char *)pi->name, "target") == 0);
        assert(strcmp((const char *)pi->content, "data!") == 0);
        xmlFreeNode(pi);
    }
#endif
}

#ifndef XML3_REFERENCE_TEST
static unsigned int rejected_case;

static void test_encoding_boundaries(void) {
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 16);
    char *mapping = mmap(NULL, (size_t)page * 2, PROT_READ | PROT_WRITE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert(mapping != MAP_FAILED);
    assert(mprotect(mapping + page, (size_t)page, PROT_NONE) == 0);
    xmlDocPtr doc = xmlReadMemory("<r/>", 4, NULL, NULL, 0);
    assert(doc);
    xmlNodePtr root = xmlDocGetRootElement(doc);
    assert(root);
    const xmlDocPtr invalid_docs[] = {NULL, (xmlDocPtr)1,
        (xmlDocPtr)(mapping + page), (xmlDocPtr)root};
    static const char bad[][7] = {"X", "", "U", "UT", "UTF", "UTF-", "UTF-8X", "\xff"};
    static const size_t lengths[] = {1, 1, 2, 3, 4, 5, 6, 1};
    for (int format = 0; format <= 1; ++format) {
        xmlChar *memory;
        int size;
        for (size_t i = 0; i < sizeof(lengths) / sizeof(*lengths); ++i) {
            char *encoding = mapping + page - lengths[i];
            memcpy(encoding, bad[i], lengths[i]);
            memory = (xmlChar *)1;
            size = 77;
            xmlResetLastError();
            if (format)
                xmlDocDumpFormatMemoryEnc(doc, &memory, &size, encoding, format);
            else
                xmlDocDumpMemoryEnc(doc, &memory, &size, encoding);
            assert(memory == NULL && size == 0);
            assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        }
        for (size_t i = 0; i < sizeof(invalid_docs) / sizeof(*invalid_docs); ++i) {
            memory = (xmlChar *)1;
            size = 77;
            xmlResetLastError();
            xmlDocDumpFormatMemoryEnc(invalid_docs[i], &memory, &size,
                                      mapping + page, format);
            assert(memory == NULL && size == 0);
            assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        }
        size = 77;
        xmlResetLastError();
        xmlDocDumpFormatMemoryEnc(doc, NULL, &size, mapping + page, format);
        assert(size == 0);
        assert(xmlGetLastError() && xmlGetLastError()->code == 115);
        for (unsigned int mask = 0; mask < 8; ++mask) {
            char name[] = "UTF-8", declaration[32];
            for (unsigned int i = 0; i < 3; ++i)
                if (mask & (1u << i)) name[i] += 'a' - 'A';
            char *encoding = mapping + page - sizeof(name);
            memcpy(encoding, name, sizeof(name));
            snprintf(declaration, sizeof(declaration), "encoding=\"%s\"", name);
            xmlResetLastError();
            xmlDocDumpFormatMemoryEnc(doc, &memory, &size, encoding, format);
            assert(memory && size > 0 && memory[size] == 0);
            assert(strstr((const char *)memory, declaration));
            assert(memcmp(encoding, name, sizeof(name)) == 0);
            assert(xmlGetLastError() == NULL);
            xmlFree(memory);
        }
        assert(xmlDocGetRootElement(doc) == root);
    }
    xmlFreeDoc(doc);
    assert(munmap(mapping, (size_t)page * 2) == 0);
}

static void expect_rejected(xmlDocPtr doc, const char *encoding) {
    xmlChar *memory = (xmlChar *)1;
    int size = 77;

    xmlResetLastError();
    xmlDocDumpMemoryEnc(doc, &memory, &size, encoding);
    if (memory != NULL || size != 0) {
        fprintf(stderr, "rejection case %u (encoding %s): size %d, output %s\n",
                rejected_case, encoding != NULL ? encoding : "(null)", size,
                memory != NULL ? (const char *)memory : "(null)");
    }
    rejected_case++;
    assert(memory == NULL && size == 0);
    assert(xmlGetLastError() != NULL);
}

static void test_round_trip(void) {
    static const char input[] =
        "<?xml version='1.0' encoding='UTF-8'?>"
        "<?before data?><!--top-->"
        "<名 xmlns='urn:default' xmlns:q='urn:q' "
        "q:属性='a&amp;&quot;&#9;&#10;' plain='v' empty=''>"
        "A&amp;&lt;&gt;&#13;<![CDATA[x]]]]><![CDATA[>y]]><!--inside-->"
        "<?inside value?>"
        "</名><!--after-->";
    static const char expected_text_before[] = "A&<>\rx]]>y";
    static const char expected_text[] = "A&<>\rx]]>y追加&<>\r";
    static const char expected_attribute[] = "a&\"\t\n";
    static const char expected_edited_attribute[] = "x&\"y\t\n";
    xmlDocPtr doc = xmlReadMemory(input, (int)sizeof(input) - 1, NULL, NULL, 0);
    xmlNodePtr root;
    xmlChar *attribute;
    xmlChar *content;
    xmlChar *edited_attribute;
    xmlNsPtr q_namespace;
    xmlChar *memory = NULL;
    int size = 0;
    xmlDocPtr reparsed;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    assert(root != NULL);
    attribute = xmlGetNsProp(root, BAD_CAST "属性", BAD_CAST "urn:q");
    content = xmlNodeGetContent(root);
    assert(attribute != NULL && strcmp((const char *)attribute,
                                       expected_attribute) == 0);
    assert(content != NULL &&
           strcmp((const char *)content, expected_text_before) == 0);
    xmlFree(attribute);
    xmlFree(content);
    q_namespace = xmlSearchNs(doc, root, BAD_CAST "q");
    assert(q_namespace != NULL);
    assert(xmlSetNsProp(root, q_namespace, BAD_CAST "追記",
                        BAD_CAST "x&\"y\t\n") != NULL);
    assert(xmlAddChild(root, xmlNewText(BAD_CAST "追加&<>\r")) != NULL);

    xmlChar *encoding = xmlStrdup(BAD_CAST "uTf-8");
    assert(encoding);
    xmlDocDumpMemoryEnc(doc, &memory, &size, (const char *)encoding);
    xmlFree(encoding);
    assert(memory != NULL && size > 0 && memory[size] == 0);
    assert(strstr((const char *)memory, "encoding=\"uTf-8\"") != NULL);
    assert(strstr((const char *)memory, "<名") != NULL);
    assert(strstr((const char *)memory, "&quot;&#9;&#10;") != NULL);
    assert(strstr((const char *)memory, "]]]]><![CDATA[>") != NULL);
    xmlFreeDoc(doc);

    reparsed = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(reparsed != NULL);
    root = xmlDocGetRootElement(reparsed);
    attribute = xmlGetNsProp(root, BAD_CAST "属性", BAD_CAST "urn:q");
    edited_attribute = xmlGetNsProp(root, BAD_CAST "追記", BAD_CAST "urn:q");
    {
        xmlChar *empty = xmlGetProp(root, BAD_CAST "empty");
        assert(empty != NULL && strcmp((const char *)empty, "") == 0);
        xmlFree(empty);
    }
    content = xmlNodeGetContent(root);
    assert(attribute != NULL && strcmp((const char *)attribute,
                                       expected_attribute) == 0);
    assert(edited_attribute != NULL &&
           strcmp((const char *)edited_attribute,
                  expected_edited_attribute) == 0);
    assert(content != NULL && strcmp((const char *)content, expected_text) == 0);
    xmlFree(attribute);
    xmlFree(edited_attribute);
    xmlFree(content);
    xmlFreeDoc(reparsed);
    assert(strstr((const char *)memory, "<名") != NULL);
    xmlFree(memory);
}

static void test_misc_rejections_and_lifetime(int affiliated) {
    static const struct { const char *target; const char *content; } cases[] = {
        {NULL, "bad--comment"}, {NULL, "trailing-"},
        {NULL, "\001"}, {NULL, "\xc3"},
        {"xml", ""}, {"xmL", ""}, {"xMl", ""}, {"xML", ""},
        {"Xml", ""}, {"XmL", ""}, {"XMl", ""}, {"XML", ""},
        {"", ""}, {"bad name", ""}, {"ok", "?>"}, {"ok", "\001"}
    };
    size_t i;
    for (i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        xmlDocPtr doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
        xmlNodePtr node = cases[i].target
            ? (affiliated
               ? xmlNewDocPI(doc, BAD_CAST cases[i].target, BAD_CAST cases[i].content)
               : xmlNewPI(BAD_CAST cases[i].target, BAD_CAST cases[i].content))
            : (affiliated ? xmlNewDocComment(doc, BAD_CAST cases[i].content)
               : xmlNewComment(BAD_CAST cases[i].content));
        xmlChar *memory = NULL;
        int size = 0;
        assert(doc && root && node);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, node) == node);
        expect_rejected(doc, "UTF-8");
        assert(root->children == node && node->parent == root);
        xmlUnlinkNode(node);
        xmlFreeNode(node);
        xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
        assert(memory && strstr((const char *)memory, "<r/>"));
        xmlFree(memory);
        xmlFreeDoc(doc);
    }
    {
        xmlDocPtr doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
        xmlNodePtr comment = affiliated
            ? xmlNewDocComment(doc, BAD_CAST "retained comment")
            : xmlNewComment(BAD_CAST "retained comment");
        xmlNodePtr pi = affiliated
            ? xmlNewDocPI(doc, BAD_CAST "retained", BAD_CAST "PI data")
            : xmlNewPI(BAD_CAST "retained", BAD_CAST "PI data");
        xmlChar *content;
        assert(doc && root && comment && pi);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, comment) == comment);
        assert(xmlAddChild(root, pi) == pi);
        xmlUnlinkNode(comment);
        xmlUnlinkNode(pi);
        xmlFreeDoc(doc);
        content = xmlNodeGetContent(comment);
        assert(content && strcmp((const char *)content, "retained comment") == 0);
        xmlFree(content);
        content = xmlNodeGetContent(pi);
        assert(content && strcmp((const char *)content, "PI data") == 0);
        xmlFree(content);
        assert(strcmp((const char *)pi->name, "retained") == 0);
        xmlFreeNode(comment);
        xmlFreeNode(pi);
    }
}

static void test_pointer_contracts(void) {
    xmlDocPtr doc = xmlReadMemory("<r/>", 4, NULL, NULL, 0);
    xmlChar *memory = NULL;
    int size = 1;

    assert(doc != NULL);
    xmlDocDumpMemoryEnc(doc, NULL, &size, "UTF-8");
    assert(size == 0);
    xmlDocDumpMemoryEnc(doc, &memory, NULL, "UTF-8");
    assert(memory != NULL);
    xmlFree(memory);
    memory = (xmlChar *)1;
    size = 99;
    xmlDocDumpMemoryEnc(NULL, &memory, &size, "UTF-8");
    assert(memory == NULL && size == 0);
    xmlDocDumpMemory(doc, &memory, NULL);
    assert(memory && strcmp((const char *)memory,
                            "<?xml version=\"1.0\"?>\n<r/>\n") == 0);
    xmlFree(memory);
    xmlDocDumpMemory(doc, NULL, &size);
    assert(size == 0);
    memory = (xmlChar *)1;
    size = 99;
    xmlDocDumpMemory(NULL, &memory, &size);
    assert(memory == NULL && size == 0);
    xmlDocDumpFormatMemory(doc, NULL, &size, 1);
    assert(size == 0);
    xmlDocDumpFormatMemoryEnc(doc, &memory, NULL, "UTF-8", 1);
    assert(memory);
    xmlFree(memory);
    memory = (xmlChar *)1;
    size = 99;
    xmlDocDumpFormatMemory(NULL, &memory, &size, 1);
    assert(memory == NULL && size == 0);
    xmlDocDumpFormatMemoryEnc(doc, &memory, &size, "UTF-16", 1);
    assert(memory == NULL && size == 0);
    expect_rejected((xmlDocPtr)xmlDocGetRootElement(doc), NULL);
    xmlDoc unmanaged = {0};
    expect_rejected(&unmanaged, NULL);
    expect_rejected(doc, "");
    expect_rejected(doc, "UTF-16");
    xmlFreeDoc(doc);
}

static void test_default_rejections_and_metadata(void) {
    const char *invalid[] = {"\1", "\xc3", "\xc0\xaf", "\xef\xbf\xbe"};
    for (size_t i = 0; i < sizeof(invalid) / sizeof(*invalid); ++i) {
        xmlDocPtr doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
        assert(doc && root && xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, xmlNewText(BAD_CAST invalid[i])));
        expect_rejected(doc, NULL);
        xmlChar *memory = (xmlChar *)1;
        int size = 99;
        xmlResetLastError();
        xmlDocDumpMemory(doc, &memory, &size);
        assert(memory == NULL && size == 0 && xmlGetLastError());
        xmlDocDumpFormatMemory(doc, &memory, &size, 1);
        assert(memory == NULL && size == 0);
        assert(xmlNodeSetContent(root, BAD_CAST "fixed") == 0);
        xmlDocDumpMemory(doc, &memory, &size);
        assert(memory && strstr((const char *)memory, "<r>fixed</r>"));
        xmlFree(memory);
        xmlFreeDoc(doc);
    }
    /* The declared encoding is the document's (doc->encoding), which a
     * serialization without an encoding uses, as in libxml2. */
    expect_default_output("<?xml version='1.0' encoding='UTF-8'?><r>é</r>",
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<r>é</r>\n");
    xmlResetLastError();
}

static void test_namespace_shadowing(void) {
    static const char input[] =
        "<r xmlns:p='urn:outer'><p:a><p:b xmlns:p='urn:inner' p:id='1'/>"
        "</p:a></r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)sizeof(input) - 1, NULL, NULL, 0);
    xmlChar *memory = NULL;
    xmlChar *value;
    int size = 0;
    xmlNodePtr inner;

    assert(doc != NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && strstr((const char *)memory,
                                    "<p:b xmlns:p=\"urn:inner\" p:id=\"1\"/>"));
    xmlFreeDoc(doc);
    doc = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(doc != NULL);
    inner = xmlDocGetRootElement(doc)->children->children;
    assert(inner != NULL && inner->type == XML_ELEMENT_NODE);
    value = xmlGetNsProp(inner,
                         BAD_CAST "id", BAD_CAST "urn:inner");
    assert(value != NULL && strcmp((const char *)value, "1") == 0);
    xmlFree(value);
    xmlFreeDoc(doc);
    xmlFree(memory);
}

static void test_namespace_escaping(void) {
    static const char uri[] = "urn:a&\"b\tc\nd";
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNsPtr ns;
    xmlChar *memory = NULL;
    int size = 0;

    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    ns = xmlNewNs(root, BAD_CAST uri, BAD_CAST "p");
    assert(ns != NULL);
    xmlSetNs(root, ns);
    assert(xmlNewProp(root, BAD_CAST "nil", NULL) != NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && strstr((const char *)memory,
        "xmlns:p=\"urn:a&amp;&quot;b&#9;c&#10;d\"") != NULL);
    assert(strstr((const char *)memory, "nil=\"\"") != NULL);
    xmlFreeDoc(doc);
    doc = xmlReadMemory((const char *)memory, size, NULL, NULL, 0);
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    assert(root->ns != NULL && strcmp((const char *)root->ns->href, uri) == 0);
    xmlFreeDoc(doc);
    xmlFree(memory);
}

static void test_empty_document(void) {
    static const char expected[] =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlChar *memory = NULL;
    int size = 0;

    assert(doc != NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && size == (int)sizeof(expected) - 1);
    assert(memcmp(memory, expected, (size_t)size) == 0);
    xmlFree(memory);
    xmlFreeDoc(doc);
}

static void expect_invalid_namespace_binding(const char *href,
                                             const char *prefix) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");

    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlNewNs(root, BAD_CAST href, BAD_CAST prefix) != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);
}

static void test_empty_namespace_attribute_rejection(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNsPtr empty;

    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    empty = xmlNewNs(root, BAD_CAST "", NULL);
    assert(empty != NULL);
    assert(xmlNewNsProp(root, empty, BAD_CAST "a", BAD_CAST "1") != NULL);
    assert(xmlNewProp(root, BAD_CAST "a", BAD_CAST "2") != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);

    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "r");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    empty = xmlNewNs(root, BAD_CAST "", NULL);
    assert(empty != NULL);
    assert(xmlNewNsProp(root, empty, BAD_CAST "xmlns", BAD_CAST "value") != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);
}

static void test_safer_rejections(void) {
    xmlDocPtr doc;
    xmlNodePtr root;
    xmlNodePtr child;
    xmlNsPtr first;
    xmlNsPtr second;

    doc = xmlNewDoc(BAD_CAST "1.1");
    assert(doc != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);

    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "r");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlNewProp(root, BAD_CAST "xmlns", BAD_CAST "urn:invalid") != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);

    expect_invalid_namespace_binding("urn:invalid", "xmlns");
    expect_invalid_namespace_binding("http://www.w3.org/2000/xmlns/", "p");
    expect_invalid_namespace_binding("http://www.w3.org/XML/1998/namespace",
                                     "p");
    expect_invalid_namespace_binding("", "p");
    expect_invalid_namespace_binding("urn:invalid", "");
    expect_invalid_namespace_binding("urn:invalid", "bad prefix");

    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "r");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlNewNs(root, BAD_CAST "urn:invalid",
                    BAD_CAST "xml") != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);

    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "bad name");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);

    {
        static const char control[] = {1, 0};
        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "r");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, xmlNewText(BAD_CAST control)) != NULL);
        expect_rejected(doc, "UTF-8");
        xmlFreeDoc(doc);
    }

    {
        static const char malformed[] = {(char)0xc3, 0};
        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "r");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, xmlNewText(BAD_CAST malformed)) != NULL);
        expect_rejected(doc, "UTF-8");
        xmlFreeDoc(doc);
    }

    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "r");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    first = xmlNewNs(root, BAD_CAST "urn:same", BAD_CAST "p");
    second = xmlNewNs(root, BAD_CAST "urn:same", BAD_CAST "q");
    assert(first != NULL && second != NULL);
    assert(xmlNewNsProp(root, first, BAD_CAST "a", BAD_CAST "1") != NULL);
    assert(xmlNewNsProp(root, second, BAD_CAST "a", BAD_CAST "2") != NULL);
    expect_rejected(doc, "UTF-8");
    xmlFreeDoc(doc);

    {
        static const char source[] = "<r xmlns='urn:default'><child/></r>";
        doc = xmlReadMemory(source, (int)sizeof(source) - 1, NULL, NULL, 0);
    }
    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    child = root->children;
    assert(child != NULL && child->type == XML_ELEMENT_NODE);
    xmlSetNs(child, NULL);
    expect_rejected(doc, "UTF-8");
    assert(xmlNewNs(child, BAD_CAST "", NULL) != NULL);
    {
        xmlChar *memory = NULL;
        int size = 0;
        xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
        assert(memory != NULL && strstr((const char *)memory,
                                        "xmlns=\"\"") != NULL);
        xmlFree(memory);
    }
    xmlFreeDoc(doc);
}

static void test_borrowed_namespace_scope(void) {
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNsPtr borrowed;
    xmlChar *memory = NULL;
    int size = 0;

    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    borrowed = xmlNewNs(NULL, BAD_CAST "urn:borrowed", BAD_CAST "p");
    assert(borrowed != NULL);
    xmlSetNs(root, borrowed);
    expect_rejected(doc, "UTF-8");
    assert(root->ns == borrowed && root->nsDef == NULL);
    assert(xmlNewNs(root, BAD_CAST "urn:borrowed", BAD_CAST "p") != NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && strstr((const char *)memory,
                                    "xmlns:p=\"urn:borrowed\"") != NULL);
    assert(root->ns == borrowed);
    xmlFree(memory);
    xmlFreeDoc(doc);
    xmlFreeNs(borrowed);
}

static void test_large_text_and_depth(void) {
#ifdef XML3_DEVELOPMENT_TEST
    size_t length = 256;
    const size_t depth = 32;
#else
    size_t length = 70 * 1024;
    const size_t depth = 12000;
#endif
    char *large = malloc(length + 1);
    xmlDocPtr doc = xmlNewDoc(NULL);
    xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "r");
    xmlNodePtr cursor;
    xmlChar *memory = NULL;
    int size = 0;
    size_t i;

    assert(large != NULL && doc != NULL && root != NULL);
    memset(large, '&', length);
    large[length] = 0;
    assert(xmlDocSetRootElement(doc, root) == NULL);
    assert(xmlAddChild(root, xmlNewText(BAD_CAST large)) != NULL);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    {
        static const char prefix[] =
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<r>";
        static const char suffix[] = "</r>\n";
        size_t expected_size = strlen(prefix) + length * 5 + strlen(suffix);
        assert(size == (int)expected_size && memory[size] == 0);
        assert(strstr((const char *)memory, "&amp;&amp;&amp;") != NULL);
        {
            xmlDocPtr reparsed = xmlReadMemory((const char *)memory, size,
                                                NULL, NULL, 0);
            xmlChar *content;
            assert(reparsed != NULL);
            content = xmlNodeGetContent(xmlDocGetRootElement(reparsed));
            assert(content != NULL);
            {
                size_t content_length;
                for (content_length = 0;
                     content_length <= length && content[content_length] != 0;
                     ++content_length)
                {
                }
                assert(content_length == length);
            }
            assert(memcmp(content, large, length) == 0);
            xmlFree(content);
            xmlFreeDoc(reparsed);
        }
    }
    xmlFree(memory);
    xmlFreeDoc(doc);
    free(large);

    doc = xmlNewDoc(NULL);
    root = xmlNewNode(NULL, BAD_CAST "n");
    assert(doc != NULL && root != NULL);
    assert(xmlDocSetRootElement(doc, root) == NULL);
    cursor = root;
    for (i = 1; i < depth; ++i) {
        xmlNodePtr next = xmlNewNode(NULL, BAD_CAST "n");
        assert(next != NULL && xmlAddChild(cursor, next) == next);
        cursor = next;
    }
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(size > (int)(depth * 7) && memory[size] == 0);
    xmlFree(memory);
    xmlFreeDoc(doc);
}

#if !defined(XML3_DEVELOPMENT_TEST) && !defined(XML3_NO_OOM_TEST)
static void test_serialization_oom(void) {
    static const char input[] = "<r a='v'>text</r>";
    xmlDocPtr doc = xmlReadMemory(input, (int)sizeof(input) - 1,
                                  NULL, NULL, 0);
    xmlNodePtr root;
    xmlChar *memory = NULL;
    int size = 19;
    int injected;

    assert(doc != NULL);
    root = xmlDocGetRootElement(doc);
    assert(root != NULL && root->properties != NULL);
    xml3_oom_enable(0);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    injected = xml3_oom_was_injected();
    xml3_oom_disable();
    assert(injected && memory == NULL && size == 0);
    assert(strcmp((const char *)root->properties->children->content, "v") == 0);
    assert(strcmp((const char *)root->children->content, "text") == 0);
    xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
    assert(memory != NULL && strstr((const char *)memory, "<r a=\"v\">text</r>"));
    xmlFree(memory);
    xmlFreeDoc(doc);
}
#endif

int main(int argc, char **argv) {
    test_xml_property_input();
    test_set_input();
    test_append_input();
    test_string_list_input();
    test_container_input();
    test_pi_target_input();
    test_content_input();
    test_document_version_input();
    if (argc == 2 && strcmp(argv[1], "--misc") == 0) {
        test_cdata_construction();
        test_constructed_comments_and_pi(0);
        test_constructed_comments_and_pi(1);
        test_document_misc_lifetime();
        test_misc_rejections_and_lifetime(0);
        test_misc_rejections_and_lifetime(1);
        puts("comment and PI construction tests passed");
        return 0;
    }
    test_shared_lexical_cases();
    test_round_trip();
    test_encoding_boundaries();
    test_cdata_construction();
    test_constructed_comments_and_pi(0);
    test_constructed_comments_and_pi(1);
    test_document_misc_lifetime();
    test_misc_rejections_and_lifetime(0);
    test_misc_rejections_and_lifetime(1);
    test_pointer_contracts();
    test_default_serialization();
    test_formatted_serialization();
    test_parsed_pi_content();
    test_default_rejections_and_metadata();
    test_namespace_shadowing();
    test_namespace_escaping();
    test_empty_document();
    test_safer_rejections();
    test_empty_namespace_attribute_rejection();
    test_borrowed_namespace_scope();
    test_large_text_and_depth();
#if !defined(XML3_DEVELOPMENT_TEST) && !defined(XML3_NO_OOM_TEST)
    test_serialization_oom();
#endif
    puts("UTF-8 memory serialization tests passed");
    return 0;
}

#else
int main(void) {
    test_xml_property_input();
    test_set_input();
    test_append_input();
    test_string_list_input();
    test_container_input();
    test_pi_target_input();
    test_content_input();
    test_document_version_input();
    test_default_serialization();
    test_formatted_serialization();
    test_parsed_pi_content();
    test_shared_lexical_cases();
    test_cdata_construction();
    test_constructed_comments_and_pi(0);
    test_constructed_comments_and_pi(1);
    test_document_misc_lifetime();
    puts("reference UTF-8 serializer lexical case passed");
    return 0;
}
#endif
