#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <libxml/tree.h>

static void *blocks[3];
static void *facades[3];
static unsigned free_counts[3];
static int private_marker;

enum {
    MERGE_TARGET_BLOCK,
    MERGE_SOURCE_CONTENT,
    MERGE_SOURCE_BLOCK,
    MERGE_OLD_CONTENT,
    MERGE_NEW_CONTENT,
    MERGE_ALLOCATION_COUNT
};

static void *merge_blocks[MERGE_ALLOCATION_COUNT];
static void *merge_facades[2];
static unsigned merge_free_counts[MERGE_ALLOCATION_COUNT];
static void *constructor_blocks[3];
static void *constructor_facades[3];
static void *constructor_namespace;
static unsigned constructor_free_counts[3];
static int fail_next_malloc;
static xmlNode *store_merge_root, *store_merge_target, *store_merge_source;
static void *store_merge_source_block;
static unsigned store_merge_source_frees;

void bridge_store_merge_track(xmlNode *root, xmlNode *target, xmlNode *source) {
    store_merge_root = root;
    store_merge_target = target;
    store_merge_source = source;
    store_merge_source_block = (size_t *)source - 1;
    store_merge_source_frees = 0;
}

void bridge_store_merge_check(int merged) {
    assert(store_merge_root->children == store_merge_target);
    assert(store_merge_root->last == store_merge_target);
    assert(store_merge_target->parent == store_merge_root);
    assert(store_merge_target->prev == NULL && store_merge_target->next == NULL);
    assert(strcmp((const char *)store_merge_target->content,
                  merged ? "abcd" : "ab") == 0);
    assert(store_merge_source_frees == (merged ? 1u : 0u));
    if (!merged) {
        assert(store_merge_source->parent == NULL);
        assert(strcmp((const char *)store_merge_source->content, "cd") == 0);
    }
}

void bridge_store_merge_reset(void) {
    assert(store_merge_source_frees == 1);
    store_merge_root = store_merge_target = store_merge_source = NULL;
    store_merge_source_block = NULL;
}

void * __real_malloc(size_t);
void bridge_check_live(xmlDoc *, xmlNode *, xmlNode *, xmlNs *);

void bridge_fail_next_malloc(void) {
    fail_next_malloc = 1;
}

void * __wrap_malloc(size_t size) {
    if (fail_next_malloc) {
        fail_next_malloc = 0;
        return NULL;
    }
    return __real_malloc(size);
}

void bridge_merge_reset_tracking(void) {
    for (unsigned i = 0; i < MERGE_ALLOCATION_COUNT; ++i) {
        assert(merge_free_counts[i] == 1);
        merge_blocks[i] = NULL;
        merge_free_counts[i] = 0;
    }
    merge_facades[0] = NULL;
    merge_facades[1] = NULL;
}

void bridge_constructor_track(void *doc_block, void *root_block,
                             void *text_block, void *doc, void *root,
                             void *text, void *ns) {
    constructor_blocks[0] = doc_block;
    constructor_blocks[1] = root_block;
    constructor_blocks[2] = text_block;
    constructor_facades[0] = doc;
    constructor_facades[1] = root;
    constructor_facades[2] = text;
    constructor_namespace = ns;
    for (unsigned i = 0; i < 3; ++i) {
        assert(constructor_blocks[i] != NULL);
        assert(constructor_facades[i] != NULL);
        constructor_free_counts[i] = 0;
    }
    assert(constructor_namespace != NULL);
}

unsigned bridge_constructor_free_count(unsigned index) {
    assert(index < 3);
    return constructor_free_counts[index];
}

void bridge_constructor_reset_tracking(void) {
    for (unsigned i = 0; i < 3; ++i) {
        assert(constructor_free_counts[i] == 1);
        constructor_blocks[i] = NULL;
        constructor_facades[i] = NULL;
        constructor_free_counts[i] = 0;
    }
    constructor_namespace = NULL;
}

void bridge_constructor_check_live(void *doc, void *root, void *text, void *ns) {
    const xmlDoc *document = doc;
    const xmlNode *element = root;
    const xmlNode *content = text;
    const xmlNs *namespace = ns;
    bridge_check_live((xmlDoc *)document, (xmlNode *)element, (xmlNode *)content,
                      (xmlNs *)namespace);
    assert(*((const size_t *)doc - 1) == 1);
    assert(*((const size_t *)root - 1) == 2);
    assert(*((const size_t *)text - 1) == 3);
    assert(*((const size_t *)ns - 1) == 1);
}

void bridge_track(void *doc_block, void *root_block, void *child_block,
                  void *doc, void *root, void *child) {
    blocks[0] = doc_block;
    blocks[1] = root_block;
    blocks[2] = child_block;
    facades[0] = doc;
    facades[1] = root;
    facades[2] = child;
}

void bridge_reset_tracking(void) {
    for (unsigned i = 0; i < 3; ++i) {
        assert(free_counts[i] == 1);
        blocks[i] = NULL;
        facades[i] = NULL;
        free_counts[i] = 0;
    }
}

void bridge_merge_track(void *target_block, void *source_content,
                        void *source_block, void *old_content,
                        void *new_content, void *target, void *source) {
    merge_blocks[MERGE_TARGET_BLOCK] = target_block;
    merge_blocks[MERGE_SOURCE_CONTENT] = source_content;
    merge_blocks[MERGE_SOURCE_BLOCK] = source_block;
    merge_blocks[MERGE_OLD_CONTENT] = old_content;
    merge_blocks[MERGE_NEW_CONTENT] = new_content;
    merge_facades[0] = target;
    merge_facades[1] = source;
    for (unsigned i = 0; i < MERGE_ALLOCATION_COUNT; ++i) {
        assert(merge_blocks[i] != NULL);
        merge_free_counts[i] = 0;
    }
    assert(target != NULL && source != NULL && target != source);
}

unsigned bridge_merge_free_count(unsigned index) {
    assert(index < MERGE_ALLOCATION_COUNT);
    return merge_free_counts[index];
}

static void merge_check_target_content(void) {
    const xmlNode *target = merge_facades[0];
    assert(merge_free_counts[MERGE_TARGET_BLOCK] == 0);
    assert(target != NULL && target->content != NULL);
    assert(target->content == (xmlChar *)merge_blocks[MERGE_NEW_CONTENT]);
    assert(strcmp((const char *)target->content, "abcd") == 0);
}

static void merge_check_source_cleared(void) {
    const xmlNode *source;
    assert(merge_free_counts[MERGE_SOURCE_BLOCK] == 0);
    source = merge_facades[1];
    assert(source != NULL);
    assert(source->children == NULL && source->last == NULL);
    assert(source->parent == NULL && source->next == NULL && source->prev == NULL);
    assert(source->doc == NULL && source->ns == NULL && source->content == NULL);
    assert(source->properties == NULL && source->nsDef == NULL);
}

void bridge_merge_check_initial(void) {
    const xmlNode *target = merge_facades[0];
    const xmlNode *source = merge_facades[1];
    assert(merge_free_counts[MERGE_TARGET_BLOCK] == 0);
    assert(merge_free_counts[MERGE_SOURCE_BLOCK] == 0);
    assert(target != NULL && target->content != NULL);
    assert(source != NULL && source->content != NULL);
    assert(target->content == (xmlChar *)merge_blocks[MERGE_OLD_CONTENT]);
    assert(source->content == (xmlChar *)merge_blocks[MERGE_SOURCE_CONTENT]);
    assert(strcmp((const char *)target->content, "ab") == 0);
    assert(strcmp((const char *)source->content, "cd") == 0);
}

void bridge_merge_check_pending(void) {
    bridge_merge_check_initial();
}

void bridge_merge_check_target(void) {
    merge_check_target_content();
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
    if (pointer != NULL && pointer == store_merge_source_block) {
        assert(store_merge_source_frees == 0);
        assert(store_merge_source->parent == NULL);
        assert(store_merge_source->content == NULL);
        ++store_merge_source_frees;
        bridge_store_merge_check(1);
    }
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
    for (unsigned i = 0; i < MERGE_ALLOCATION_COUNT; ++i) {
        if (pointer != merge_blocks[i] || pointer == NULL)
            continue;
        assert(merge_free_counts[i] == 0);
        if (i == MERGE_SOURCE_CONTENT || i == MERGE_SOURCE_BLOCK ||
            i == MERGE_OLD_CONTENT)
            merge_check_target_content();
        if (i == MERGE_SOURCE_CONTENT || i == MERGE_SOURCE_BLOCK)
            merge_check_source_cleared();
        ++merge_free_counts[i];
        break;
    }
    for (unsigned i = 0; i < 3; ++i) {
        if (pointer != constructor_blocks[i] || pointer == NULL)
            continue;
        assert(constructor_free_counts[i] == 0);
        for (unsigned j = 0; j < 3; ++j) {
            if (constructor_free_counts[j] != 0)
                continue;
            const xmlNode *node = constructor_facades[j];
            assert(node->children == NULL && node->last == NULL);
            assert(node->parent == NULL && node->next == NULL && node->prev == NULL);
            assert(node->doc == NULL && node->ns == NULL && node->content == NULL);
            assert(node->properties == NULL && node->nsDef == NULL);
        }
        ++constructor_free_counts[i];
        break;
    }
    __real_free(pointer);
}
