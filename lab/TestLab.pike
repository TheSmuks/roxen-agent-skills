// A real Roxen module, used to prove that code calling Roxen APIs compiles and
// runs inside a live server — not against stubs, and not merely on the module
// path.
//
// It deliberately exercises the call that started this: the combination of
// sprintf and Roxen.html_encode_string that fails outside a booted Roxen.

#include <module.h>

inherit "module";

constant cvs_version = "lab test module";
constant thread_safe = 1;

constant module_type = MODULE_LOCATION | MODULE_TAG;
constant module_name = "Lab Test Module";
constant module_doc  = "Verifies that Roxen APIs resolve inside a running server.";

void create()
{
  defvar("mountpoint", "/labtest/", "Mount point", TYPE_LOCATION,
         "Where this module answers.");
}

string query_location() { return query("mountpoint"); }

//! The original failing case: html_encode_string over a sprintf result.
string encoded_probe()
{
  mixed last_seen = ([ "a": 1, "b": ({ 2, 3 }) ]);
  return Roxen.html_encode_string(sprintf("%O", last_seen));
}

mixed find_file(string path, RequestID id)
{
  if (path == "probe") {
    // Touch a few genuinely Roxen-only things so a stub could not satisfy this:
    //   Roxen.html_encode_string  - the module under test
    //   id->not_query             - RequestID member
    //   id->misc                  - the per-request mapping
    string body = sprintf(
      "LABTEST OK\n"
      "encoded=%s\n"
      "not_query=%s\n"
      "misc_is_mapping=%d\n",
      encoded_probe(),
      Roxen.html_encode_string(id->not_query || ""),
      mappingp(id->misc));
    return Roxen.http_string_answer(body, "text/plain");
  }
  return 0;
}

//! An RXML tag, to prove the RXML side resolves too. The class must be named
//! Tag* or query_tag_set() will never find it.
class TagLabtest
{
  inherit RXML.Tag;
  constant name = "labtest";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      result = "labtest-tag-ok";
      return 0;
    }
  }
}
