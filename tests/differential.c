#include <libxml/parser.h>
#include <libxml/tree.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef XML3_REFERENCE_VERSION
#if LIBXML_VERSION != XML3_REFERENCE_VERSION
#error Wrong reference headers
#endif
#endif

static void string_value(const xmlChar *value) {
    if (!value) {
        fputs("null", stdout);
        return;
    }
    for (; *value; ++value) printf("%02x", (unsigned)*value);
}

static void namespace_value(const xmlNs *ns) {
    if (!ns) { fputs("none", stdout); return; }
    printf("%d:", (int)ns->type);
    string_value(ns->prefix);
    fputc('=', stdout);
    string_value(ns->href);
}

static void namespace_queries(xmlNodePtr node) {
    const xmlChar *prefixes[] = {NULL, BAD_CAST "p", BAD_CAST "q", BAD_CAST "xml"};
    const xmlChar *uris[] = {BAD_CAST "urn:one", BAD_CAST "urn:two", BAD_CAST "", XML_XML_NAMESPACE};
    for (size_t i = 0; i < sizeof(prefixes)/sizeof(prefixes[0]); ++i) {
        fputs(" prefix:", stdout);
        namespace_value(xmlSearchNs(node->doc, node, prefixes[i]));
    }
    for (size_t i = 0; i < sizeof(uris)/sizeof(uris[0]); ++i) {
        fputs(" uri:", stdout);
        namespace_value(xmlSearchNsByHref(node->doc, node, uris[i]));
    }
}

static void dump(xmlNodePtr node) {
    for (; node; node = node->next) {
        printf("(%d ", (int)node->type);
        string_value(node->name);
        fputc(' ', stdout);
        xmlChar *content = xmlNodeGetContent(node);
        string_value(content);
        xmlFree(content);
        if (node->type == XML_ELEMENT_NODE) {
            fputs(" ns:", stdout);
            namespace_value(node->ns);
            for (xmlNsPtr ns = node->nsDef; ns; ns = ns->next) {
                fputs(" def:", stdout);
                namespace_value(ns);
            }
            namespace_queries(node);
            for (xmlAttrPtr attr = node->properties; attr; attr = attr->next) {
                fputs(" @", stdout);
                string_value(attr->name);
                fputc('=', stdout);
                xmlChar *value = xmlGetProp(node, attr->name);
                string_value(value);
                xmlFree(value);
                fputs(" ns:", stdout);
                namespace_value(attr->ns);
                fputs(" ns-value:", stdout);
                value = xmlGetNsProp(node, attr->name, attr->ns ? attr->ns->href : NULL);
                string_value(value);
                xmlFree(value);
                printf(" has:%d", xmlHasNsProp(node, attr->name, attr->ns ? attr->ns->href : NULL) == attr);
                fputs(" plain:", stdout);
                value = xmlGetNoNsProp(node, attr->name);
                string_value(value);
                xmlFree(value);
                namespace_queries((xmlNodePtr)attr);
            }
        }
        dump(node->children);
        fputc(')', stdout);
    }
}

int main(void) {
#ifdef XML3_REFERENCE_VERSION
    if (strcmp(xmlParserVersion, XML3_REFERENCE_VERSION_STRING) != 0) {
        fprintf(stderr, "wrong reference runtime: %s\n", xmlParserVersion);
        return EXIT_FAILURE;
    }
#endif
    static const char *const inputs[] = {
        "<root/>",
        "<root></root>",
        "<root a='one' b=\"two\"><child/>before<child>inside</child>after</root>",
        "<?xml version='1.0'?><root>hello</root>",
        "<?xml version=\"1.0\" encoding='UTF-8' standalone='yes'?><root/>",
        "\xef\xbb\xbf<root>\xe6\x97\xa5\xe6\x9c\xac\xf0\x9f\x98\x80</root>",
        "<root a='&lt;&gt;&amp;&apos;&quot;'>&lt;&gt;&amp;&apos;&quot;</root>",
        "<root a='&#9;&#10;&#13;'>a&#65;&#x20AC;&#x1F600;</root>",
        "<root a='a\tb\r\nc\rd\ne'>x\r\ny\rz\n</root>",
        "<!--before--><?job start?><root><!--inside--><![CDATA[<x>&raw]]><?job end?></root><!--after-->",
        "<root><a><b><c>text</c></b></a><empty/></root>",
        "<root a='' b=''><![CDATA[]]></root>",
        " \n<root> \n\t <child/> </root>\n",
        "<root><?xml-stylesheet href='local'?>tail</root>",
        "<root>&#x10FFFF;&#xD7FF;&#xE000;</root>",
        "<r xmlns='urn:one' xmlns:p='urn:p' id='plain' p:id='prefix'><p:c p:a='x'/><c xmlns=''><p:d/></c></r>",
        "<p:r a='plain' p:a='one' xmlns:p='urn:one' xmlns:q='urn:two' q:a='two'><q:c xmlns:p='urn:two'><p:d/></q:c><p:e/></p:r>",
        "<r xmlns:p='urn:one'><x xmlns:p='urn:two'><p:a/></x><p:b/></r>",
        "<r xmlns='urn:one' xmlns:p='urn:one'><x xmlns:p='urn:two' a='v'/></r>",
        "<r xml:lang='en'/>",
        "<r xmlns:xml='http://www.w3.org/XML/1998/namespace' xml:space='preserve'><xml:c/></r>",
        "<r xmlns:p='urn:&amp;one' p:a='ok'/>",
        "<r xmlns:p='urn:one' xmlns:q='urn:one' p:a='1' q:b='2'/>",
        "<r xmlns:p='urn:one'><x xmlns:q='urn:one'><q:a/></x></r>",
        "<r xmlns='urn:one' xmlns:p='urn:two'><x xmlns=''><p:y a='v'/></x></r>",
        "<?処理 開始?><名:根 xmlns:名='urn:one' 名:属性='値'><名:子/></名:根>",
        "<é><e\xcc\x81 a\xc2\xb7='v'/><\xf0\x9f\x98\x80/></é>",
        "<名:根 xmlns:名='urn:one'><名:子 xmlns:名='urn:two'/><名:子/></名:根>"
    };
    xmlInitParser();
    for (size_t i = 0; i < sizeof(inputs) / sizeof(inputs[0]); ++i) {
        xmlDocPtr doc = xmlReadMemory(inputs[i], (int)strlen(inputs[i]),
                                     NULL, NULL, XML_PARSE_NONET);
        if (!doc || !xmlDocGetRootElement(doc)) {
            fprintf(stderr, "accepted fixture %zu failed\n", i);
            return EXIT_FAILURE;
        }
        printf("%zu:", i);
        dump(doc->children);
        fputc('\n', stdout);
        xmlFreeDoc(doc);
    }
    xmlCleanupParser();
    return EXIT_SUCCESS;
}
