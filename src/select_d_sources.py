#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys
import os

list_file_name = "raw_sources.list"

source_files = []
work_dir = os.getcwd()
for root, dirs, files in os.walk( work_dir ):
	file_dir_rel = ""
	if root != os.getcwd():
		file_dir_rel = root[ len(work_dir): ]
	for file_name in files:
		if file_name.endswith('.d'):
			source_files.extend( [ (file_dir_rel + "/" + file_name)[1:] ] )

f = open(list_file_name, "w")
f.write( "\n".join(source_files) )
f.close()