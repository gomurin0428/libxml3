import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("api_inventory", ROOT / "eng/api_inventory.py")
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)


class InventoryTest(unittest.TestCase):
    def test_semantic_declarations_and_duplicate_visits(self):
        with tempfile.TemporaryDirectory() as directory:
            include = Path(directory)
            (include / "libxml").mkdir()
            (include / "libxml/example.h").write_text("""
#ifndef EXAMPLE_H
#define EXAMPLE_H
#define EXAMPLE_LIMIT (1 << 4)
#define REMOVED_MACRO 1
#undef REMOVED_MACRO
typedef void (*callback)(const char *text, void *context);
typedef struct Item Item;
struct Item { const char *name; callback notify; };
typedef enum { ITEM_FIRST = 3, ITEM_LAST = 5 } ItemKind;
extern int count;
int inspect(const Item *item);
#endif
""")
            result = api.inventory(include)
            entries = {e["id"]: e for e in result["entries"]}
            self.assertEqual(len(entries), len(result["entries"]))
            self.assertIn("callback:example.h:callback", entries)
            self.assertEqual(entries["field:example.h:Item.name"]["declaration"], "const char *")
            self.assertTrue(entries["struct:example.h:Item"]["defined"])
            self.assertEqual(entries["constant:example.h:ITEM_LAST"]["value"], 5)
            self.assertIn("variable:example.h:count", entries)
            self.assertEqual(entries["function:example.h:inspect"]["parameters"],
                             [{"name": "item", "type": "const Item *"}])
            self.assertIn("EXAMPLE_LIMIT ( 1 << 4 )", entries["macro:example.h:EXAMPLE_LIMIT"]["declaration"])
            self.assertNotIn("macro:example.h:REMOVED_MACRO", entries)

    def test_parse_error_does_not_silently_drop_api(self):
        with tempfile.TemporaryDirectory() as directory:
            include = Path(directory)
            (include / "libxml").mkdir()
            (include / "libxml/broken.h").write_text("undefined_type fn(void);")
            with self.assertRaisesRegex(ValueError, "Header parse failed"):
                api.inventory(include)

    def test_unrecognized_coverage_and_stale_report_fail(self):
        with self.assertRaisesRegex(ValueError, "unknown declaration"):
            api.validate_coverage({"entries": []}, {"missing": {}})
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "report.md"
            path.write_text("old")
            with self.assertRaisesRegex(ValueError, "Stale"):
                api.write_or_check(path, "new", True)
            self.assertEqual(path.read_text(), "old")


if __name__ == "__main__":
    unittest.main()
