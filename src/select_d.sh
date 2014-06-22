list_file="raw_sources.list"
$(find -iname '*.d'>$list_file) && $(echo -n>>$list_file)