#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <libxml/tree.h>

static void *blocks[3];
static void *facades[3];
static unsigned free_counts[3];
static int private_marker;

void bridge_track(void *doc_block, void *root_block, void *child_block,
                  void *doc, void *root, void *child) {
    blocks[0] = doc_block;
    blocks[1] = root_block;
    blocks[2] = child_block;
    facades[0] = doc;
    facades[1] = root;
    facades[2] = child;
}

void bridge_check_live(xmlDoc *doc, xmlNode *root, xmlNode *child, xmlNs *ns) {
    assert(doc->type == XML_DOCUMENT_NODE && doc->doc == doc);
    assert(doc->children == root && doc->last == root);
    assert(strcmp((const char *)doc->version, "1.0") == 0);
    assert(root->type == XML_ELEMENT_NODE && root->parent == (xmlNode *)doc);
    assert(root->doc == doc && root->ns == ns);
    assert(strcmp((const char *)root->name, "r") == 0);
    assert(root->children == child && root->last == child);
    assert(child->type == XML_TEXT_NODE && child->parent == root && child->doc == doc);
    assert(strcmp((const char *)child->name, "text") == 0);
    assert(strcmp((const char *)child->content, "x") == 0);
    assert(ns->type == XML_NAMESPACE_DECL && ns->context == NULL);
    assert(strcmp((const char *)ns->prefix, "xml") == 0);
    assert(strcmp((const char *)ns->href, (const char *)XML_XML_NAMESPACE) == 0);
    root->_private = &private_marker;
    ns->_private = &private_marker;
}

void bridge_check_detached(xmlDoc *doc, xmlNode *root, xmlNode *child, xmlNs *ns) {
    assert(doc->children == NULL && doc->last == NULL && doc->version == NULL);
    assert(root->parent == NULL && root->prev == NULL && root->next == NULL);
    assert(root->doc == doc && root->ns == ns && root->children == child);
    assert(root->_private == &private_marker && ns->_private == &private_marker);
    assert(child->parent == root && child->doc == doc);
    assert(strcmp((const char *)child->content, "x") == 0);
    assert(strcmp((const char *)ns->href, (const char *)XML_XML_NAMESPACE) == 0);
}

unsigned bridge_free_count(unsigned index) {
    assert(index < 3);
    return free_counts[index];
}

void __real_free(void *pointer);

void __wrap_free(void *pointer) {
    for (unsigned i = 0; i < 3; ++i) {
        if (pointer != blocks[i] || pointer == NULL)
            continue;
        assert(free_counts[i] == 0);
        for (unsigned j = 0; j < 3; ++j) {
            if (free_counts[j] != 0)
                continue;
            if (j == 0) {
                const xmlDoc *doc = facades[j];
                assert(doc->children == NULL && doc->last == NULL);
                assert(doc->doc == NULL && doc->version == NULL);
            } else {
                const xmlNode *node = facades[j];
                assert(node->children == NULL && node->last == NULL);
                assert(node->parent == NULL && node->next == NULL && node->prev == NULL);
                assert(node->doc == NULL && node->ns == NULL && node->content == NULL);
                assert(node->properties == NULL && node->nsDef == NULL);
            }
        }
        ++free_counts[i];
    }
    __real_free(pointer);
}
