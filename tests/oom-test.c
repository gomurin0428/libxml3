#include <libxml3.h>

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void xml3_oom_enable(long index);
void xml3_oom_disable(void);
long xml3_oom_count(void);
int xml3_oom_was_injected(void);

static char *copy_test_string(const char *value) {
    size_t length = strlen(value) + 1;
    char *copy = malloc(length);
    assert(copy != NULL);
    memcpy(copy, value, length);
    return copy;
}

static void init_test_error(xmlError *error, const char *prefix) {
    char value[64];

    memset(error, 0, sizeof(*error));
    error->domain = XML_FROM_PARSER;
    error->code = XML_ERR_INVALID_CHAR;
    error->level = XML_ERR_FATAL;
    error->line = 17;
    error->int1 = 23;
    error->int2 = 42;
#define SET_FIELD(field, suffix)             \
    do {                                      \
        snprintf(value, sizeof(value), "%s %s", prefix, suffix); \
        error->field = copy_test_string(value); \
    } while (0)
    SET_FIELD(message, "message");
    SET_FIELD(file, "file");
    SET_FIELD(str1, "str1");
    SET_FIELD(str2, "str2");
    SET_FIELD(str3, "str3");
#undef SET_FIELD
}

static void assert_error_unchanged(const xmlError *actual,
                                   const xmlError *expected) {
    assert(actual->domain == expected->domain);
    assert(actual->code == expected->code);
    assert(actual->level == expected->level);
    assert(actual->line == expected->line);
    assert(actual->int1 == expected->int1);
    assert(actual->int2 == expected->int2);
    assert(actual->ctxt == expected->ctxt);
    assert(actual->node == expected->node);
    assert(actual->message == expected->message);
    assert(actual->file == expected->file);
    assert(actual->str1 == expected->str1);
    assert(actual->str2 == expected->str2);
    assert(actual->str3 == expected->str3);
    assert(strcmp(actual->message, expected->message) == 0);
    assert(strcmp(actual->file, expected->file) == 0);
    assert(strcmp(actual->str1, expected->str1) == 0);
    assert(strcmp(actual->str2, expected->str2) == 0);
    assert(strcmp(actual->str3, expected->str3) == 0);
}

static void assert_error_copy(const xmlError *actual,
                              const xmlError *source) {
    assert(actual->domain == source->domain);
    assert(actual->code == source->code);
    assert(actual->level == source->level);
    assert(actual->line == source->line);
    assert(actual->int1 == source->int1);
    assert(actual->int2 == source->int2);
    assert(actual->message != source->message);
    assert(actual->file != source->file);
    assert(actual->str1 != source->str1);
    assert(actual->str2 != source->str2);
    assert(actual->str3 != source->str3);
    assert(strcmp(actual->message, source->message) == 0);
    assert(strcmp(actual->file, source->file) == 0);
    assert(strcmp(actual->str1, source->str1) == 0);
    assert(strcmp(actual->str2, source->str2) == 0);
    assert(strcmp(actual->str3, source->str3) == 0);
}

static const xmlError *require_oom_error(void) {
    const xmlError *error = xmlGetLastError();
    assert(error != NULL);
    assert(error->domain == XML_FROM_MEMORY);
    assert(error->code == XML_ERR_NO_MEMORY);
    assert(error->level == XML_ERR_FATAL);
    return error;
}

int main(int argc, char **argv) {
    const char *operation;
    long fail_index;
    long allocation_count;
    int injected;
    xmlDocPtr doc = NULL;
    xmlNodePtr dom_node = NULL;
    xmlNodePtr merge_left = NULL;
    xmlNodePtr merge_right = NULL;
    xmlError copy = {0};
    xmlError source = {0};
    const xmlError *error;
    int result = 0;

    assert(argc == 3);
    operation = argv[1];
    fail_index = strtol(argv[2], NULL, 10);
    xmlResetLastError();

    if (strcmp(operation, "success") == 0) {
        int status = -1;
        xml3_oom_enable(fail_index);
        doc = xml3ReadMemory("<r><x/></r>", 11, &status);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(doc == NULL);
            assert(status == XML3_STATUS_NO_MEMORY);
            require_oom_error();
        } else {
            assert(doc != NULL);
            assert(status == XML3_STATUS_OK);
            assert(xmlGetLastError() == NULL);
        }
    } else if (strcmp(operation, "malformed") == 0) {
        int status = -1;
        xml3_oom_enable(fail_index);
        doc = xml3ReadMemory("<r><x></r>", 10, &status);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(doc == NULL);
        if (injected) {
            assert(status == XML3_STATUS_NO_MEMORY);
            require_oom_error();
        } else {
            assert(status == XML3_STATUS_MALFORMED);
            error = xmlGetLastError();
            assert(error != NULL && error->code == XML_ERR_TAG_NAME_MISMATCH);
        }
    } else if (strcmp(operation, "utf16") == 0) {
        static const unsigned char input[] = {
            0xff, 0xfe, '<', 0, 'r', 0, '/', 0, '>', 0
        };
        int status = -1;
        xml3_oom_enable(fail_index);
        doc = xml3ReadMemory((const char *)input, sizeof(input), &status);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(doc == NULL);
            assert(status == XML3_STATUS_NO_MEMORY);
            require_oom_error();
        } else {
            assert(doc != NULL);
            assert(status == XML3_STATUS_OK);
            assert(xmlGetLastError() == NULL);
        }
    } else if (strcmp(operation, "warning") == 0) {
        static const unsigned char input[] = {
            0xef, 0xbb, 0xbf, '<', '?', 'x', 'm', 'l', ' ',
            'v', 'e', 'r', 's', 'i', 'o', 'n', '=', '\'', '1', '.', '0',
            '\'', ' ', 'e', 'n', 'c', 'o', 'd', 'i', 'n', 'g', '=', '\'',
            'U', 'T', 'F', '-', '1', '6', '\'', '?', '>', '<', 'r', '/', '>'
        };
        int status = -1;
        xml3_oom_enable(fail_index);
        doc = xml3ReadMemory((const char *)input, sizeof(input), &status);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(doc == NULL);
            assert(status == XML3_STATUS_NO_MEMORY);
            require_oom_error();
        } else {
            assert(doc != NULL);
            assert(status == XML3_STATUS_OK);
            error = xmlGetLastError();
            assert(error != NULL && error->code == 113);
            assert(error->level == XML_ERR_WARNING);
        }
    } else if (strcmp(operation, "copy") == 0) {
        xmlError source_before;
        xmlError destination_before;

        xml3_oom_disable();
        init_test_error(&source, "source");
        init_test_error(&copy, "destination");
        source_before = source;
        destination_before = copy;
        xml3_oom_enable(fail_index);
        result = xmlCopyError(&source, &copy);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result != 0);
            require_oom_error();
            assert_error_unchanged(&source, &source_before);
            assert_error_unchanged(&copy, &destination_before);
        } else {
            assert(result == 0);
            assert_error_unchanged(&source, &source_before);
            assert_error_copy(&copy, &source);
        }
        xmlResetError(&copy);
        xmlResetError(&source);
    } else if (strcmp(operation, "replacement") == 0) {
        assert(xmlReadMemory("<broken>", 8, NULL, NULL, 0) == NULL);
        assert(xmlGetLastError() != NULL);
        xml3_oom_enable(fail_index);
        doc = xmlReadMemory("<r><x></r>", 10, NULL, NULL, 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(doc == NULL);
        if (injected)
            require_oom_error();
        else {
            error = xmlGetLastError();
            assert(error != NULL && error->code == XML_ERR_TAG_NAME_MISMATCH);
        }
    } else if (strcmp(operation, "tls") == 0) {
        xml3_oom_enable(fail_index);
        doc = xmlReadMemory("<r/>", 4, NULL, "latin1", 0);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(doc == NULL);
        if (injected)
            require_oom_error();
        else {
            error = xmlGetLastError();
            assert(error != NULL && error->code == XML_ERR_UNSUPPORTED_ENCODING);
        }
        if (injected) {
            error = require_oom_error();
            const char *emergency_message = error->message;
            assert(xmlCopyError(error, &copy) == 0);
            assert(copy.message != NULL);
            assert(copy.message != error->message);
            assert(copy.domain == XML_FROM_MEMORY);
            assert(copy.code == XML_ERR_NO_MEMORY);
            assert(copy.level == XML_ERR_FATAL);
            xmlResetError((xmlError *)(uintptr_t)error);
            assert(xmlGetLastError() == NULL);
            assert(strcmp(emergency_message, "out of memory\n") == 0);
            assert(strcmp(copy.message, "out of memory\n") == 0);
            xmlResetError(&copy);
            assert(strcmp(emergency_message, "out of memory\n") == 0);
        }
    } else if (strcmp(operation, "dom-new-doc") == 0) {
        xml3_oom_enable(fail_index);
        doc = xmlNewDoc(NULL);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(doc == NULL);
            require_oom_error();
        } else {
            assert(doc != NULL);
            xmlFreeDoc(doc);
            doc = NULL;
            assert(xmlGetLastError() == NULL);
        }
    } else if (strcmp(operation, "dom-new-node") == 0) {
        xml3_oom_enable(fail_index);
        dom_node = xmlNewNode(NULL, BAD_CAST "new-node");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(dom_node == NULL);
            require_oom_error();
        } else {
            assert(dom_node != NULL);
            xmlFreeNode(dom_node);
            dom_node = NULL;
            assert(xmlGetLastError() == NULL);
        }
    } else if (strcmp(operation, "dom-new-text") == 0 ||
               strcmp(operation, "dom-new-comment") == 0 ||
               strcmp(operation, "dom-new-pi") == 0) {
        xml3_oom_enable(fail_index);
        dom_node = strcmp(operation, "dom-new-comment") == 0
            ? xmlNewComment(BAD_CAST "text")
            : strcmp(operation, "dom-new-pi") == 0
                ? xmlNewPI(BAD_CAST "target", BAD_CAST "text")
                : xmlNewText(BAD_CAST "text");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(dom_node == NULL);
            require_oom_error();
            dom_node = strcmp(operation, "dom-new-comment") == 0
                ? xmlNewComment(BAD_CAST "text")
                : strcmp(operation, "dom-new-pi") == 0
                    ? xmlNewPI(BAD_CAST "target", BAD_CAST "text")
                    : xmlNewText(BAD_CAST "text");
            assert(dom_node != NULL);
            xmlFreeNode(dom_node);
            dom_node = NULL;
        } else {
            assert(dom_node != NULL);
            xmlFreeNode(dom_node);
            dom_node = NULL;
            assert(xmlGetLastError() == NULL);
        }
    } else if (strcmp(operation, "dom-merge") == 0) {
        xmlNodePtr root;
        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "root");
        merge_left = xmlNewText(BAD_CAST "left");
        merge_right = xmlNewText(BAD_CAST "right");
        assert(doc != NULL && root != NULL && merge_left != NULL &&
               merge_right != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        assert(xmlAddChild(root, merge_left) == merge_left);
        xml3_oom_enable(fail_index);
        dom_node = xmlAddChild(root, merge_right);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(dom_node == NULL);
            assert(root->children == merge_left && root->last == merge_left);
            assert(merge_left->parent == root && merge_left->next == NULL);
            assert(merge_right->parent == NULL && merge_right->prev == NULL &&
                   merge_right->next == NULL);
            assert(strcmp((const char *)merge_left->content, "left") == 0);
            assert(strcmp((const char *)merge_right->content, "right") == 0);
            require_oom_error();
        } else {
            assert(dom_node == merge_left);
            assert(root->children == merge_left && root->last == merge_left);
            assert(strcmp((const char *)merge_left->content, "leftright") == 0);
            merge_right = NULL;
        }
    } else if (strcmp(operation, "attr-new") == 0) {
        xmlNodePtr root;
        xmlAttrPtr before, after, created;
        xmlNodePtr before_child, after_child;

        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "root");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        before = xmlNewProp(root, BAD_CAST "before", BAD_CAST "left");
        after = xmlNewProp(root, BAD_CAST "after", BAD_CAST "right");
        assert(before != NULL && after != NULL);
        before_child = before->children;
        after_child = after->children;
        xml3_oom_enable(fail_index);
        created = xmlNewProp(root, BAD_CAST "middle", BAD_CAST "value");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            assert(root->properties == before && before->prev == NULL);
            assert(before->next == after && after->prev == before);
            assert(after->next == NULL && before->children == before_child);
            assert(after->children == after_child);
            assert(strcmp((const char *)before_child->content, "left") == 0);
            assert(strcmp((const char *)after_child->content, "right") == 0);
            require_oom_error();
        } else {
            assert(created != NULL && root->properties == before);
            assert(before->next == after && after->prev == before);
            assert(after->next == created && created->prev == after);
            assert(created->next == NULL);
            assert(strcmp((const char *)created->children->content, "value") == 0);
            xmlFreeProp(created);
        }
    } else if (strcmp(operation, "attr-detached") == 0) {
        xmlAttrPtr created;

        xml3_oom_enable(fail_index);
        created = xmlNewProp(NULL, BAD_CAST "standalone", BAD_CAST "value");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            require_oom_error();
        } else {
            assert(created != NULL && created->parent == NULL &&
                   created->doc == NULL);
            assert(created->children != NULL);
            assert(strcmp((const char *)created->children->content, "value") == 0);
            xmlFreeProp(created);
        }
    } else if (strcmp(operation, "attr-set-new") == 0) {
        xmlNodePtr root;
        xmlAttrPtr before, after, created;
        xmlNodePtr before_child, after_child;

        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "root");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        before = xmlNewProp(root, BAD_CAST "before", BAD_CAST "left");
        after = xmlNewProp(root, BAD_CAST "after", BAD_CAST "right");
        assert(before != NULL && after != NULL);
        before_child = before->children;
        after_child = after->children;
        xml3_oom_enable(fail_index);
        created = xmlSetProp(root, BAD_CAST "added", BAD_CAST "value");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            assert(root->properties == before && before->prev == NULL);
            assert(before->next == after && after->prev == before);
            assert(after->next == NULL && before->children == before_child);
            assert(after->children == after_child);
            assert(strcmp((const char *)before_child->content, "left") == 0);
            assert(strcmp((const char *)after_child->content, "right") == 0);
            require_oom_error();
        } else {
            assert(created != NULL && root->properties == before);
            assert(before->next == after && after->prev == before);
            assert(after->next == created && created->prev == after);
            assert(created->next == NULL);
            assert(strcmp((const char *)created->children->content, "value") == 0);
            xmlFreeProp(created);
        }
    } else if (strcmp(operation, "attr-set") == 0) {
        static const char input[] =
            "<root before='left' target='old' after='right'/>";
        xmlNodePtr root;
        xmlAttrPtr before, target, after, result_attr;
        xmlNodePtr old_children;
        xmlChar *old_content;
        int private_marker;

        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc != NULL);
        root = xmlDocGetRootElement(doc);
        before = root->properties;
        assert(before != NULL);
        target = before->next;
        assert(target != NULL);
        after = target->next;
        assert(after != NULL);
        old_children = target->children;
        old_content = old_children->content;
        target->_private = &private_marker;
        xml3_oom_enable(fail_index);
        result_attr = xmlSetProp(root, BAD_CAST "target", BAD_CAST "replacement");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result_attr == NULL);
            assert(root->properties == before && before->prev == NULL);
            assert(before->next == target && target->prev == before);
            assert(target->next == after && after->prev == target);
            assert(after->next == NULL && target->_private == &private_marker);
            assert(target->children == old_children);
            assert(old_children->content == old_content);
            assert(strcmp((const char *)old_content, "old") == 0);
            require_oom_error();
        } else {
            assert(result_attr == target);
            assert(root->properties == before && before->next == target);
            assert(target->prev == before && target->next == after);
            assert(after->prev == target && after->next == NULL);
            assert(target->_private == &private_marker);
            assert(target->children != old_children);
            assert(strcmp((const char *)target->children->content,
                          "replacement") == 0);
        }
    } else if (strcmp(operation, "ns-new") == 0) {
        xmlNodePtr root;
        xmlNsPtr first, second, created;

        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "root");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        first = xmlNewNs(root, BAD_CAST "urn:first", BAD_CAST "p");
        second = xmlNewNs(root, BAD_CAST "urn:second", BAD_CAST "q");
        assert(first != NULL && second != NULL);
        xml3_oom_enable(fail_index);
        created = xmlNewNs(root, BAD_CAST "urn:third", BAD_CAST "r");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            assert(root->nsDef == first && first->next == second);
            assert(second->next == NULL);
            assert(strcmp((const char *)first->href, "urn:first") == 0);
            assert(strcmp((const char *)second->href, "urn:second") == 0);
            require_oom_error();
        } else {
            assert(created != NULL && root->nsDef == first);
            assert(first->next == second && second->next == created);
            assert(created->next == NULL);
            assert(strcmp((const char *)created->href, "urn:third") == 0);
            assert(strcmp((const char *)created->prefix, "r") == 0);
        }
    } else if (strcmp(operation, "ns-detached") == 0) {
        xmlNsPtr created;

        xml3_oom_enable(fail_index);
        created = xmlNewNs(NULL, BAD_CAST "urn:detached", BAD_CAST "d");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            require_oom_error();
        } else {
            assert(created != NULL && created->context == NULL);
            assert(strcmp((const char *)created->href, "urn:detached") == 0);
            assert(strcmp((const char *)created->prefix, "d") == 0);
            xmlFreeNs(created);
        }
    } else if (strcmp(operation, "ns-prop-new") == 0) {
        xmlNodePtr root;
        xmlNsPtr ns;
        xmlAttrPtr before, after, created;
        xmlNodePtr before_child, after_child;

        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "root");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        ns = xmlNewNs(root, BAD_CAST "urn:qualified", BAD_CAST "p");
        before = xmlNewProp(root, BAD_CAST "before", BAD_CAST "left");
        after = xmlNewProp(root, BAD_CAST "after", BAD_CAST "right");
        assert(ns != NULL && before != NULL && after != NULL);
        before_child = before->children;
        after_child = after->children;
        xml3_oom_enable(fail_index);
        created = xmlNewNsProp(root, ns, BAD_CAST "middle", BAD_CAST "value");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            assert(root->properties == before && before->prev == NULL);
            assert(before->next == after && after->prev == before);
            assert(after->next == NULL && before->children == before_child);
            assert(after->children == after_child);
            assert(root->nsDef == ns && ns->next == NULL);
            assert(strcmp((const char *)ns->href, "urn:qualified") == 0);
            assert(strcmp((const char *)before_child->content, "left") == 0);
            assert(strcmp((const char *)after_child->content, "right") == 0);
            require_oom_error();
        } else {
            assert(created != NULL && root->properties == before);
            assert(before->next == after && after->prev == before);
            assert(after->next == created && created->prev == after);
            assert(created->next == NULL && created->ns == ns);
            assert(strcmp((const char *)created->children->content, "value") == 0);
            xmlFreeProp(created);
        }
    } else if (strcmp(operation, "ns-prop-set") == 0) {
        static const char input[] =
            "<root xmlns:p='urn:same' xmlns:q='urn:same' "
            "before='left' p:a='old' after='right'/>";
        xmlNodePtr root;
        xmlNsPtr old_ns, alias;
        xmlAttrPtr before, target, after, result_attr;
        xmlNodePtr old_children;
        xmlChar *old_content;
        int private_marker;

        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc != NULL);
        root = xmlDocGetRootElement(doc);
        old_ns = root->nsDef;
        assert(old_ns != NULL);
        alias = old_ns->next;
        before = root->properties;
        assert(before != NULL);
        target = before->next;
        assert(target != NULL);
        after = target->next;
        assert(after != NULL);
        assert(alias != NULL && alias != old_ns);
        assert(target->ns == old_ns && target->children != NULL);
        old_children = target->children;
        old_content = old_children->content;
        target->_private = &private_marker;
        xml3_oom_enable(fail_index);
        result_attr = xmlSetNsProp(root, alias, BAD_CAST "a",
                                   BAD_CAST "replacement");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result_attr == NULL);
            assert(root->properties == before && before->prev == NULL);
            assert(before->next == target && target->prev == before);
            assert(target->next == after && after->prev == target);
            assert(after->next == NULL && target->ns == old_ns);
            assert(target->_private == &private_marker);
            assert(target->children == old_children);
            assert(old_children->content == old_content);
            assert(strcmp((const char *)old_content, "old") == 0);
            require_oom_error();
        } else {
            assert(result_attr == target && target->ns == alias);
            assert(root->properties == before && before->next == target);
            assert(target->prev == before && target->next == after);
            assert(after->prev == target && after->next == NULL);
            assert(target->_private == &private_marker);
            assert(target->children != old_children);
            assert(strcmp((const char *)target->children->content,
                          "replacement") == 0);
        }
    } else if (strcmp(operation, "ns-qname-set") == 0) {
        static const char input[] =
            "<root xmlns:p='urn:qualified' before='left' after='right'/>";
        xmlNodePtr root;
        xmlNsPtr ns;
        xmlAttrPtr before, after, created;
        xmlNodePtr before_child, after_child;

        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc != NULL);
        root = xmlDocGetRootElement(doc);
        ns = root->nsDef;
        before = root->properties;
        assert(ns != NULL && before != NULL);
        after = before->next;
        assert(after != NULL && after->next == NULL);
        before_child = before->children;
        after_child = after->children;
        xml3_oom_enable(fail_index);
        created = xmlSetProp(root, BAD_CAST "p:created", BAD_CAST "value");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL);
            assert(root->nsDef == ns && ns->next == NULL);
            assert(root->properties == before && before->prev == NULL);
            assert(before->next == after && after->prev == before);
            assert(after->next == NULL && before->children == before_child);
            assert(after->children == after_child);
            assert(strcmp((const char *)before_child->content, "left") == 0);
            assert(strcmp((const char *)after_child->content, "right") == 0);
            assert(strcmp((const char *)ns->href, "urn:qualified") == 0);
            require_oom_error();
        } else {
            assert(created != NULL && created->ns == ns);
            assert(root->properties == before && before->next == after);
            assert(after->next == created && created->prev == after);
            assert(created->next == NULL);
            assert(strcmp((const char *)created->children->content, "value") == 0);
            xmlFreeProp(created);
        }
    } else if (strcmp(operation, "ns-xml-qname") == 0) {
        xmlNodePtr root;
        xmlNsPtr ns;
        xmlAttrPtr created;

        root = xmlNewNode(NULL, BAD_CAST "root");
        assert(root != NULL && root->doc == NULL);
        xml3_oom_enable(fail_index);
        created = xmlSetProp(root, BAD_CAST "xml:lang", BAD_CAST "ja");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(created == NULL && root->properties == NULL);
            assert(root->nsDef == NULL);
            require_oom_error();
        } else {
            assert(created != NULL && root->properties == created);
            ns = root->nsDef;
            assert(ns != NULL && created->ns == ns);
            assert(xmlSearchNs(NULL, root, BAD_CAST "xml") == ns);
            assert(strcmp((const char *)created->children->content, "ja") == 0);
        }
        xmlFreeNode(root);
    } else if (strcmp(operation, "dom-content-replace") == 0) {
        xmlNodePtr text = xmlNewText(BAD_CAST "old");
        xmlChar *original_content;
        assert(text != NULL);
        original_content = text->content;
        xml3_oom_enable(fail_index);
        result = xmlNodeAddContent(text, BAD_CAST "-new");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1);
            assert(text->content == original_content);
            assert(strcmp((const char *)text->content, "old") == 0);
            require_oom_error();
            assert(xmlNodeAddContent(text, BAD_CAST "-new") == 0);
            assert(strcmp((const char *)text->content, "old-new") == 0);
        } else {
            assert(result == 0);
            assert(strcmp((const char *)text->content, "old-new") == 0);
        }
        xmlFreeNode(text);
    } else if (strcmp(operation, "dom-content-child") == 0) {
        xmlDocPtr content_doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
        xmlNodePtr comment = xmlNewComment(BAD_CAST "before");
        xmlChar *original_comment_content;
        assert(content_doc != NULL && root != NULL && comment != NULL);
        original_comment_content = comment->content;
        assert(xmlDocSetRootElement(content_doc, root) == NULL);
        assert(xmlAddChild(root, comment) == comment);
        xml3_oom_enable(fail_index);
        result = xmlNodeAddContent(root, BAD_CAST "after");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1);
            assert(root->children == comment && root->last == comment);
            assert(comment->parent == root && comment->next == NULL);
            assert(comment->content == original_comment_content);
            assert(strcmp((const char *)comment->content, "before") == 0);
            require_oom_error();
            assert(xmlNodeAddContent(root, BAD_CAST "after") == 0);
            assert(root->children == comment && root->last != comment);
            assert(comment->next == root->last && comment->next->prev == comment);
            assert(root->last->type == XML_TEXT_NODE);
            assert(strcmp((const char *)root->last->content, "after") == 0);
        } else {
            assert(result == 0);
            assert(root->children == comment && root->last != comment);
            assert(comment->next == root->last);
            assert(root->last->type == XML_TEXT_NODE);
            assert(strcmp((const char *)root->last->content, "after") == 0);
        }
        xmlFreeDoc(content_doc);
    } else if (strcmp(operation, "dom-new-child") == 0 ||
               strcmp(operation, "dom-new-text-child") == 0) {
        int raw = strcmp(operation, "dom-new-text-child") == 0;
        xmlNodePtr (*construct_child)(xmlNodePtr, xmlNsPtr, const xmlChar *,
                                      const xmlChar *) = raw ? xmlNewTextChild : xmlNewChild;
        xmlDocPtr content_doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
        xmlNodePtr old = xmlNewComment(BAD_CAST "before");
        xmlNodePtr child;
        xmlNsPtr ns;
        assert(content_doc != NULL && root != NULL && old != NULL);
        assert(xmlDocSetRootElement(content_doc, root) == NULL);
        assert(xmlAddChild(root, old) == old);
        ns = xmlNewNs(root, BAD_CAST "urn:parent", BAD_CAST "p");
        assert(ns != NULL);
        xmlSetNs(root, ns);
        xml3_oom_enable(fail_index);
        child = construct_child(root, NULL, BAD_CAST "child", BAD_CAST "new&amp;text");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(child == NULL);
            assert(root->children == old && root->last == old && root->ns == ns);
            assert(old->parent == root && old->next == NULL && old->prev == NULL);
            assert(strcmp((const char *)ns->href, "urn:parent") == 0);
            require_oom_error();
            child = construct_child(root, NULL, BAD_CAST "child", BAD_CAST "new&amp;text");
        }
        assert(child != NULL && child->parent == root && child->doc == content_doc);
        assert(child->ns == ns && root->last == child && child->prev == old);
        assert(root->children == old && old->next == child && child->next == NULL);
        assert(child->children != NULL && child->children->doc == content_doc);
        assert(strcmp((const char *)child->children->content,
                      raw ? "new&amp;text" : "new&text") == 0);
        xmlFreeDoc(content_doc);
    } else if (strcmp(operation, "dom-content-set-scalar") == 0 ||
               strcmp(operation, "dom-content-set-len") == 0) {
        int bounded = strcmp(operation, "dom-content-set-len") == 0;
        xmlNodePtr text = xmlNewText(BAD_CAST "old");
        xmlChar *original_content;
        assert(text != NULL);
        original_content = text->content;
        xml3_oom_enable(fail_index);
        result = bounded
            ? xmlNodeSetContentLen(text, BAD_CAST "replacement-ignored", 11)
            : xmlNodeSetContent(text, BAD_CAST "replacement");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1);
            assert(text->content == original_content);
            assert(strcmp((const char *)text->content, "old") == 0);
            require_oom_error();
            assert((bounded
                ? xmlNodeSetContentLen(text, BAD_CAST "replacement-ignored", 11)
                : xmlNodeSetContent(text, BAD_CAST "replacement")) == 0);
            assert(strcmp((const char *)text->content, "replacement") == 0);
        } else {
            assert(result == 0);
            assert(strcmp((const char *)text->content, "replacement") == 0);
        }
        xmlFreeNode(text);
    } else if (strcmp(operation, "dom-content-set-tree") == 0 ||
               strcmp(operation, "dom-content-set-tree-len") == 0) {
        int bounded = strcmp(operation, "dom-content-set-tree-len") == 0;
        xmlDocPtr content_doc = xmlNewDoc(NULL);
        xmlNodePtr root = xmlNewNode(NULL, BAD_CAST "root");
        xmlNodePtr child = xmlNewNode(NULL, BAD_CAST "old");
        xmlNodePtr nested = xmlNewNode(NULL, BAD_CAST "nested");
        xmlNodePtr tail = xmlNewComment(BAD_CAST "tail");
        xmlNodePtr borrower = xmlNewNode(NULL, BAD_CAST "borrower");
        xmlNsPtr ns;
        assert(content_doc != NULL && root != NULL && child != NULL &&
               nested != NULL && tail != NULL && borrower != NULL);
        assert(xmlDocSetRootElement(content_doc, root) == NULL);
        assert(xmlAddChild(child, nested) == nested);
        assert(xmlAddChild(root, child) == child);
        assert(xmlAddChild(root, tail) == tail);
        ns = xmlNewNs(child, BAD_CAST "urn:retired", BAD_CAST "p");
        assert(ns != NULL);
        xmlSetNs(borrower, ns);
        assert(borrower->ns == ns);
        xml3_oom_enable(fail_index);
        result = bounded
            ? xmlNodeSetContentLen(root, BAD_CAST "replacement-ignored", 11)
            : xmlNodeSetContent(root, BAD_CAST "replacement");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(result == -1);
            assert(root->children == child && root->last == tail);
            assert(child->parent == root && child->next == tail);
            assert(tail->parent == root && tail->prev == child);
            assert(child->children == nested && nested->parent == child);
            assert(child->nsDef == ns && borrower->ns == ns);
            assert(strcmp((const char *)ns->href, "urn:retired") == 0);
            require_oom_error();
            assert((bounded
                ? xmlNodeSetContentLen(root, BAD_CAST "replacement-ignored", 11)
                : xmlNodeSetContent(root, BAD_CAST "replacement")) == 0);
            assert(root->children == root->last);
            assert(root->children->type == XML_TEXT_NODE);
            assert(strcmp((const char *)root->children->content,
                          "replacement") == 0);
        } else {
            assert(result == 0);
            assert(root->children == root->last);
            assert(root->children->type == XML_TEXT_NODE);
            assert(strcmp((const char *)root->children->content,
                          "replacement") == 0);
        }
        assert(borrower->ns == ns);
        assert(strcmp((const char *)ns->href, "urn:retired") == 0);
        xmlFreeDoc(content_doc);
        assert(borrower->ns == ns);
        assert(strcmp((const char *)ns->href, "urn:retired") == 0);
        xmlFreeNode(borrower);
    } else if (strcmp(operation, "serialization") == 0) {
        static const char input[] = "<r a='v'>text</r>";
        xmlNodePtr root;
        xmlChar *memory = (xmlChar *)1;
        int size = 77;

        doc = xmlReadMemory(input, (int)sizeof(input) - 1, NULL, NULL, 0);
        assert(doc != NULL);
        root = xmlDocGetRootElement(doc);
        assert(root != NULL && root->properties != NULL);
        xml3_oom_enable(fail_index);
        xmlDocDumpMemoryEnc(doc, &memory, &size, "UTF-8");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        if (injected) {
            assert(memory == NULL && size == 0);
            require_oom_error();
        } else {
            assert(memory != NULL && size > 0);
            xmlFree(memory);
        }
        assert(strcmp((const char *)root->properties->children->content, "v") == 0);
        assert(strcmp((const char *)root->children->content, "text") == 0);
    } else if (strcmp(operation, "ns-noalloc") == 0) {
        xmlNodePtr node = xmlNewNode(NULL, BAD_CAST "node");
        xmlNsPtr first = xmlNewNs(NULL, BAD_CAST "urn:first", BAD_CAST "p");
        xmlNsPtr second = xmlNewNs(NULL, BAD_CAST "urn:second", BAD_CAST "q");
        assert(node != NULL && first != NULL && second != NULL);

        xml3_oom_enable(0);
        xmlSetNs(node, first);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0 && node->ns == first);

        xml3_oom_enable(0);
        xmlSetNs(node, second);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0 && node->ns == second);

        xml3_oom_enable(0);
        xmlSetNs(node, NULL);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0 && node->ns == NULL);

        xml3_oom_enable(0);
        xmlFreeNs(first);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);

        xml3_oom_enable(0);
        xmlFreeNs(second);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
        xmlFreeNode(node);
    } else if (strcmp(operation, "attr-delete") == 0) {
        xmlNodePtr root;
        xmlAttrPtr first, second, third;

        doc = xmlNewDoc(NULL);
        root = xmlNewNode(NULL, BAD_CAST "root");
        assert(doc != NULL && root != NULL);
        assert(xmlDocSetRootElement(doc, root) == NULL);
        first = xmlNewProp(root, BAD_CAST "first", BAD_CAST "one");
        second = xmlNewProp(root, BAD_CAST "second", BAD_CAST "two");
        third = xmlNewProp(root, BAD_CAST "third", BAD_CAST "three");
        assert(first != NULL && second != NULL && third != NULL);
        xml3_oom_enable(0);
        result = xmlRemoveProp(first);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(result == 0 && !injected && allocation_count == 0);
        assert(root->properties == second && second->prev == NULL);
        assert(second->next == third && third->prev == second);
        xml3_oom_enable(0);
        xmlFreeProp(second);
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(!injected && allocation_count == 0);
        assert(root->properties == third && third->prev == NULL);
        xml3_oom_enable(0);
        result = xmlUnsetProp(root, BAD_CAST "third");
        injected = xml3_oom_was_injected();
        allocation_count = xml3_oom_count();
        xml3_oom_disable();
        assert(result == 0 && !injected && allocation_count == 0);
        assert(root->properties == NULL);
    } else {
        assert(0);
        return 1;
    }
    if (doc != NULL)
        xmlFreeDoc(doc);
    if (merge_right != NULL)
        xmlFreeNode(merge_right);
    xmlResetLastError();
    doc = xmlReadMemory("<recovered/>", 12, NULL, NULL, 0);
    assert(doc != NULL);
    xmlFreeDoc(doc);
    assert(xmlGetLastError() == NULL);
    if (strcmp(operation, "attr-delete") == 0) {
        puts("attribute deletion used no allocations");
        return 0;
    }
    if (strcmp(operation, "ns-noalloc") == 0) {
        puts("namespace setters and standalone free used no allocations");
        return 0;
    }
    if (!injected)
        return 2;
    printf("allocation failure hit: operation=%s index=%ld count=%ld\n",
           operation, fail_index, allocation_count);
    return 0;
}
