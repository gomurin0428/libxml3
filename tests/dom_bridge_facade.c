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

static void *import_arena;
static xmlDoc *import_doc, *import_original;
static xmlNode *import_root, *import_text;
static xmlNs *import_ns;
static xmlDoc import_original_snapshot;
static unsigned import_frees, import_failures;
static size_t import_failure_size;
static unsigned fail_malloc_nth, malloc_calls, injected_malloc_failures;
static void *failure_allocations[3];
static unsigned failure_allocation_count;
static int failure_allocation_freed[3], track_failure_allocations;
static void *materialize_arena;
static xmlDoc *materialize_doc;
static xmlNode *materialize_nodes[12];
static xmlNs *materialize_namespaces[4];
static unsigned materialize_frees;

void bridge_import_track(void *arena, xmlDoc *doc, xmlNode *root,
                         xmlNode *text, xmlNs *ns, xmlDoc *original) {
    assert(import_arena == NULL);
    import_arena = arena;
    import_doc = doc;
    import_root = root;
    import_text = text;
    import_ns = ns;
    import_original = original;
    import_original_snapshot = *original;
    import_frees = 0;
}

void bridge_import_fail_allocation(size_t size) {
    assert(size > 0 && import_failure_size == 0);
    import_failure_size = size;
    import_failures = 0;
}

void bridge_import_check_allocation_failure(void) {
    assert(import_failures == 1 && import_failure_size == 0);
}

void bridge_fail_malloc_nth(unsigned nth) {
    assert(nth > 0);
    fail_malloc_nth = nth;
    malloc_calls = 0;
    injected_malloc_failures = 0;
    failure_allocation_count = 0;
    for (unsigned i = 0; i < 3; ++i) {
        failure_allocations[i] = NULL;
        failure_allocation_freed[i] = 0;
    }
    track_failure_allocations = 1;
}

void bridge_begin_malloc_tracking(void) {
    assert(fail_malloc_nth == 0 && track_failure_allocations == 0);
    malloc_calls = 0;
    injected_malloc_failures = 0;
    failure_allocation_count = 0;
    for (unsigned i = 0; i < 3; ++i) {
        failure_allocations[i] = NULL;
        failure_allocation_freed[i] = 0;
    }
    track_failure_allocations = 1;
}

void bridge_end_malloc_tracking(void) {
    assert(fail_malloc_nth == 0 && injected_malloc_failures == 0);
    assert(failure_allocation_count == 3);
    for (unsigned i = 0; i < failure_allocation_count; ++i)
        assert(failure_allocation_freed[i] == 1);
    track_failure_allocations = 0;
}

void bridge_check_malloc_failure(void) {
    assert(fail_malloc_nth == 0 && injected_malloc_failures == 1);
    for (unsigned i = 0; i < failure_allocation_count; ++i)
        assert(failure_allocation_freed[i] == 1);
    track_failure_allocations = 0;
}

unsigned bridge_import_free_count(void) {
    return import_frees;
}

void bridge_import_check_live(void) {
    assert(import_frees == 0);
    bridge_check_live(import_doc, import_root, import_text, import_ns);
    assert(*((size_t *)import_doc - 1) == 2);
    assert(*((size_t *)import_root - 1) == 3);
    assert(*((size_t *)import_text - 1) == 4);
    assert(*((size_t *)import_ns - 1) == 1);
    assert(memcmp(import_original, &import_original_snapshot,
                  sizeof(import_original_snapshot)) == 0);
}

void bridge_import_check_retained(void) {
    assert(import_frees == 0);
    assert(import_doc->children == NULL && import_doc->version == NULL);
    assert(import_root->parent == NULL);
    assert(import_root->children == import_text && import_root->last == import_text);
    assert(import_text->parent == import_root);
    assert(strcmp((const char *)import_root->name, "r") == 0);
    assert(strcmp((const char *)import_text->content, "x") == 0);
    assert(strcmp((const char *)import_ns->href,
                  "http://www.w3.org/XML/1998/namespace") == 0);
}

void bridge_import_reset(void) {
    assert(import_frees == 1 && import_failure_size == 0);
    import_arena = NULL;
    import_doc = import_original = NULL;
    import_root = import_text = NULL;
    import_ns = NULL;
}

void bridge_fail_next_malloc(void) {
    fail_next_malloc = 1;
}

void * __wrap_malloc(size_t size) {
    if (size == import_failure_size && size != 0) {
        import_failure_size = 0;
        ++import_failures;
        return NULL;
    }
    if (fail_malloc_nth != 0 && ++malloc_calls == fail_malloc_nth) {
        fail_malloc_nth = 0;
        ++injected_malloc_failures;
        return NULL;
    }
    if (fail_next_malloc) {
        fail_next_malloc = 0;
        return NULL;
    }
    void *result = __real_malloc(size);
    if (track_failure_allocations && result != NULL) {
        assert(failure_allocation_count < 3);
        failure_allocations[failure_allocation_count++] = result;
    }
    return result;
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

void bridge_materialize_check
  (xmlDoc *doc, xmlNode *before, xmlNode *root, xmlNode *attr,
   xmlNode *attr_value, xmlNode *lang, xmlNode *lang_value,
   xmlNode *text, xmlNode *cdata, xmlNode *comment, xmlNode *pi,
   xmlNode *child, xmlNs *implicit, xmlNs *def, xmlNs *prefix, xmlNs *empty) {
    assert(doc->type == XML_DOCUMENT_NODE && doc->doc == doc);
    assert(strcmp((const char *)doc->version, "1.0") == 0);
    assert(doc->children == before && before->next == root);
    assert(before->type == XML_PI_NODE && strcmp((const char *)before->name, "before") == 0);
    assert(strcmp((const char *)before->content, "x") == 0);
    assert(root->type == XML_ELEMENT_NODE && root->parent == (xmlNode *)doc);
    assert(strcmp((const char *)root->name, "r") == 0);
    assert((xmlNode *)root->properties == attr && attr->next == lang);
    assert(strcmp((const char *)attr->name, "a") == 0);
    assert(attr->content == NULL && attr->children == attr_value);
    assert(strcmp((const char *)attr_value->content, "A&B") == 0);
    assert(strcmp((const char *)lang->name, "lang") == 0);
    assert(lang->ns == implicit);
    assert(lang->children == lang_value);
    assert(strcmp((const char *)lang_value->content, "ja") == 0);
    assert(root->children == text && text->next == cdata && cdata->next == comment);
    assert(comment->next == pi && pi->next == child && child->next == NULL);
    assert(strcmp((const char *)text->content, "one") == 0);
    assert(strcmp((const char *)cdata->content, "two") == 0);
    assert(strcmp((const char *)comment->content, "c") == 0);
    assert(strcmp((const char *)pi->name, "pi") == 0);
    assert(strcmp((const char *)pi->content, "x") == 0);
    assert(strcmp((const char *)child->name, "c") == 0);
    assert(root->nsDef == def && def->next == prefix && prefix->next == NULL);
    assert(strcmp((const char *)def->href, "urn:d") == 0 && def->prefix == NULL);
    assert(strcmp((const char *)prefix->href, "urn:p") == 0);
    assert(strcmp((const char *)prefix->prefix, "p") == 0);
    assert(child->nsDef == empty && empty->href != NULL
           && ((const char *)empty->href)[0] == '\0' && empty->prefix == NULL);
    assert(root->ns == def && attr->ns == prefix && child->ns == prefix);
    assert(implicit->context == NULL && strcmp((const char *)implicit->prefix, "xml") == 0);
}

void bridge_materialize_track
  (void *arena, xmlDoc *doc, xmlNode *before, xmlNode *root,
   xmlNode *attr, xmlNode *attr_value, xmlNode *lang, xmlNode *lang_value,
   xmlNode *text, xmlNode *cdata, xmlNode *comment, xmlNode *pi,
   xmlNode *child, xmlNs *implicit, xmlNs *def, xmlNs *prefix, xmlNs *empty) {
    assert(materialize_arena == NULL);
    materialize_arena = arena;
    materialize_doc = doc;
    materialize_nodes[0] = before;
    materialize_nodes[1] = root;
    materialize_nodes[2] = attr;
    materialize_nodes[3] = attr_value;
    materialize_nodes[4] = lang;
    materialize_nodes[5] = lang_value;
    materialize_nodes[6] = text;
    materialize_nodes[7] = cdata;
    materialize_nodes[8] = comment;
    materialize_nodes[9] = pi;
    materialize_nodes[10] = child;
    materialize_namespaces[0] = implicit;
    materialize_namespaces[1] = def;
    materialize_namespaces[2] = prefix;
    materialize_namespaces[3] = empty;
    materialize_frees = 0;
}

void bridge_materialize_check_retained(xmlNode *root, xmlNode *attr,
                                       xmlNode *attr_value, xmlNode *lang,
                                       xmlNode *lang_value, xmlNode *text,
                                       xmlNode *cdata, xmlNode *comment,
                                       xmlNode *pi, xmlNode *child,
                                       xmlNs *implicit, xmlNs *def,
                                       xmlNs *prefix, xmlNs *empty) {
    assert(root->parent == NULL && root->prev == NULL && root->next == NULL);
    assert(root->properties == (xmlAttr *)attr && root->children == text);
    assert(attr->children == attr_value && lang->children == lang_value);
    assert(text->next == cdata && cdata->next == comment);
    assert(comment->next == pi && pi->next == child);
    assert(root->nsDef == def && def->next == prefix && child->nsDef == empty);
    assert(strcmp((const char *)attr_value->content, "A&B") == 0);
    assert(strcmp((const char *)lang_value->content, "ja") == 0);
    assert(strcmp((const char *)child->name, "c") == 0);
    assert(lang->ns == implicit);
    assert(strcmp((const char *)implicit->prefix, "xml") == 0);
    assert(strcmp((const char *)implicit->href,
                  (const char *)XML_XML_NAMESPACE) == 0);
    assert(strcmp((const char *)prefix->href, "urn:p") == 0);
    assert(empty->href != NULL && ((const char *)empty->href)[0] == '\0');
}

unsigned bridge_free_count(unsigned index) {
    assert(index < 3);
    return free_counts[index];
}

void __real_free(void *pointer);

void __wrap_free(void *pointer) {
    if (track_failure_allocations && pointer != NULL) {
        for (unsigned i = 0; i < failure_allocation_count; ++i) {
            if (pointer == failure_allocations[i]) {
                assert(failure_allocation_freed[i] == 0);
                failure_allocation_freed[i] = 1;
            }
        }
    }
    if (pointer != NULL && pointer == materialize_arena) {
        assert(materialize_frees == 0);
        assert(materialize_doc->children == NULL && materialize_doc->last == NULL);
        assert(materialize_doc->doc == NULL && materialize_doc->version == NULL);
        for (unsigned i = 0; i < 11; ++i) {
            const xmlNode *node = materialize_nodes[i];
            assert(node->name == NULL && node->content == NULL);
            assert(node->children == NULL && node->last == NULL);
            assert(node->parent == NULL && node->prev == NULL && node->next == NULL);
            assert(node->doc == NULL && node->ns == NULL);
            assert(node->properties == NULL && node->nsDef == NULL);
        }
        for (unsigned i = 0; i < 4; ++i) {
            const xmlNs *ns = materialize_namespaces[i];
            assert(ns->href == NULL && ns->prefix == NULL && ns->next == NULL);
        }
        ++materialize_frees;
    }
    if (pointer != NULL && pointer == import_arena) {
        assert(import_frees == 0);
        assert(import_doc->children == NULL && import_doc->last == NULL);
        assert(import_doc->doc == NULL && import_doc->version == NULL);
        const xmlNode *nodes[] = {import_root, import_text};
        for (unsigned i = 0; i < 2; ++i) {
            const xmlNode *node = nodes[i];
            assert(node->name == NULL && node->content == NULL);
            assert(node->children == NULL && node->last == NULL);
            assert(node->parent == NULL && node->prev == NULL && node->next == NULL);
            assert(node->doc == NULL && node->ns == NULL);
            assert(node->properties == NULL && node->nsDef == NULL);
        }
        assert(import_ns->href == NULL && import_ns->prefix == NULL && import_ns->next == NULL);
        ++import_frees;
    }
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

unsigned bridge_materialize_free_count(void) {
    return materialize_frees;
}

void bridge_materialize_reset(void) {
    assert(materialize_frees == 1);
    materialize_arena = NULL;
    materialize_doc = NULL;
    for (unsigned i = 0; i < 12; ++i)
        materialize_nodes[i] = NULL;
    for (unsigned i = 0; i < 4; ++i)
        materialize_namespaces[i] = NULL;
    materialize_frees = 0;
}
