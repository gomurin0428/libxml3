with Interfaces.C;

--  The diagnostics libxml2 2.15.4 publishes when the input of xmlReadFile
--  cannot be opened or read (xmlCtxtErrIO): the XML_IO_* codes, the text
--  xmlErrString gives each, and the level.  The errno mapping itself
--  (xmlIOErr) is done next to the system calls.
package XML3_IO_Errors with SPARK_Mode is
   use type Interfaces.C.int;

   IO_Domain : constant Interfaces.C.int := 8;
   Unknown : constant Interfaces.C.int := 1500;
   Not_Found : constant Interfaces.C.int := 1524;

   Warning_Level : constant Interfaces.C.int := 1;
   Fatal_Level : constant Interfaces.C.int := 3;

   --  A file that could not be found is only a warning when the parser
   --  does not validate; every other I/O failure is fatal.
   function Level_For (Code : Interfaces.C.int) return Interfaces.C.int is
     (if Code in Not_Found | Unknown then Warning_Level else Fatal_Level)
   with Global => null;

   function Text (Code : Interfaces.C.int) return String is
     (case Code is
        when 1501 => "Permission denied",
        when 1502 => "Resource temporarily unavailable",
        when 1503 => "Bad file descriptor",
        when 1504 => "Bad message",
        when 1505 => "Resource busy",
        when 1506 => "Operation canceled",
        when 1507 => "No child processes",
        when 1508 => "Resource deadlock avoided",
        when 1509 => "Domain error",
        when 1510 => "File exists",
        when 1511 => "Bad address",
        when 1512 => "File too large",
        when 1513 => "Operation in progress",
        when 1514 => "Interrupted function call",
        when 1515 => "Invalid argument",
        when 1516 => "Input/output error",
        when 1517 => "Is a directory",
        when 1518 => "Too many open files",
        when 1519 => "Too many links",
        when 1520 => "Inappropriate message buffer length",
        when 1521 => "Filename too long",
        when 1522 => "Too many open files in system",
        when 1523 => "No such device",
        when 1524 => "No such file or directory",
        when 1525 => "Exec format error",
        when 1526 => "No locks available",
        when 1527 => "Not enough space",
        when 1528 => "No space left on device",
        when 1529 => "Function not implemented",
        when 1530 => "Not a directory",
        when 1531 => "Directory not empty",
        when 1532 => "Not supported",
        when 1533 => "Inappropriate I/O control operation",
        when 1534 => "No such device or address",
        when 1535 => "Operation not permitted",
        when 1536 => "Broken pipe",
        when 1537 => "Result too large",
        when 1538 => "Read-only file system",
        when 1539 => "Invalid seek",
        when 1540 => "No such process",
        when 1541 => "Operation timed out",
        when 1542 => "Improper link",
        when 1550 => "not a socket",
        when 1551 => "already connected",
        when 1552 => "connection refused",
        when 1553 => "unreachable network",
        when 1554 => "address in use",
        when 1555 => "already in use",
        when 1556 => "unknown address family",
        when others => "Unknown IO error")
   with Global => null, Post => Text'Result'Length > 0;

   --  The message of a failure to open Name ("failed to load"), or of a
   --  failure to read the opened input, without the trailing newline.
   function Open_Message (Name : String; Code : Interfaces.C.int)
     return String
   is ("failed to load """ & Name & """: " & Text (Code))
   with Global => null,
     Pre => Name'Length <= Natural'Last - 64;

end XML3_IO_Errors;
