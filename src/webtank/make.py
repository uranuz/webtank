#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys
import os
import os.path

#Определяем входные параметры скрипта
projects_dir = None #Путь к корню всей группы проектов относительно текущей
out_file_name = None #Путь к проекту отностительно корня

source_lists_rel = []

for i in range( 1, len(sys.argv) ):
	if( not sys.argv[i].startswith("-") ):
		source_lists_rel.append( sys.argv[i] )
	
	if( sys.argv[i].startswith("--projdir=") ):
		projects_dir = sys.argv[i][len("--projdir=") :]
		
	if( sys.argv[i].startswith("--outfname=") ):
		out_file_name = sys.argv[i][len("--outfname=") :]

#Если не получилось определить, то ставим по-умолчанию
if( projects_dir == None ):
	projects_dir = "./"

if( out_file_name == None ):
	out_file_name = os.path.relpath("./", "../")
	if( out_file_name == "." ):
		out_file_name = "a"
		
#print(projects_dir)
#print(out_file_name)
#print(source_lists_rel)

import_dirs = [] #Директории для импорта файлов в соответствии с файлом-списком
source_lists = [] #Полные имена файлов-списков исходников
for fname in source_lists_rel:
	if( fname[0] == '/' or fname[0] == '.' ):
		import_dirs.append( os.path.dirname(fname) + "/" )
		source_lists.append( fname )
	else:
		import_dirs.append( projects_dir + os.path.dirname(fname) + "/" )
		source_lists.append( projects_dir + fname )

all_sources = [] #Список всех исходников для компиляции
#Поочерёдно открываем все файлы-списки и формируем
#общий список файлов для компиляции
for i in range( len(source_lists) ):
	if( os.path.isfile(source_lists[i]) ):
		f = open(source_lists[i])
		source_file_names = f.readlines()
		f.close()
		for j in range( len( source_file_names ) ):
			source_name = source_file_names[j]
			#Убираем перенос в конце строки, если есть
			if( source_file_names[j][-1] == "\n" ):
				source_name = source_file_names[j][:-1]
			#Убираем обозначение текущей папки, если есть
			if( source_name[0:2] == "./" ):
				source_name = source_name[2:]
			all_sources.append( import_dirs[i] + source_name )
	
#sys.stdout.write( "\n".join( all_sources ) + "\n" ) #Можно посмотреть список компилируемых файлов

#Формируем строку с командой
cmd = 'dmd ' + " ".join( all_sources ) + ' -op' + ' -of' + out_file_name
#Запускаем компиляцию
import subprocess
PIPE = subprocess.PIPE
p = subprocess.Popen(cmd, shell=True, stdin=PIPE, stdout=PIPE,
        stderr=subprocess.STDOUT, close_fds=True, cwd = os.getcwd())
sys.stdout.write( p.stdout.read() )
