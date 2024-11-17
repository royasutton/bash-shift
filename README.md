# bash-shift
Bash scripting high-level functions and tools library.

This library uses an open source [shell script loader] to manage the
loading and inclusion of script components. The loader should be
installed at: <tt>lib/shell-script-loader/v0.2.2</tt>.

[shell script loader]: https://loader.sourceforge.io/overview

 file                       | description
:---------------------------|:------------------------------------------------
 common.bash                | common helper functions
 exception.bash             | exceptions warning, errors, stack dump, functions
 exit_stat.bash             | command exit-code statistics functions
 external_command.bash      | external command management functions
 file_utility.bash          | file utility functions
 hash_table.bash            | hash table functions
 menu_cdialog.bash          | menu functions in bash
 network_account.bash       | network account functions
 parse_cmd_line.bash        | command line parsing functions
 parse_conf_file.bash       | configuration file parsing functions
 print.bash                 | console message printing functions
 print_textbox.bash         | textbox printing function
 terminal_utility.bash      | terminal utility functions
 text_utility.bash          | text utility functions
 variable_expansion.bash    | variable expansion and substitution functions
