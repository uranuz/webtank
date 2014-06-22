#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys
import os

extra_files = sys.argv[1:]

#Определяем входные параметры скрипта
projects_dir = "../../" #Путь к корню всей группы проектов относительно текущей
import_dir_rel = "webtank/src/" #Путь к проекту отностительно корня
in_list_file_rel = import_dir_rel + 'min_sources.list' #Путь к входному файлу-списку относительно корня

#Создаём список файлов для сборки библиотеки
import_dir = projects_dir + import_dir_rel
in_list_file = projects_dir + in_list_file_rel

f = open(in_list_file)
all_lines = f.readlines()
f.close()
import_files = []
for line in all_lines:
	import_files.extend( [import_dir + line[2:-1] ] )

all_sources = extra_files + import_files
#sys.stdout.write( "\n".join( extra_files ) ) #Можно посмотреть список компилируемых файлов
#sys.stdout.write("\n\n------------------------------\n")
#sys.stdout.write( "\n".join( all_sources ) ) #Можно посмотреть список компилируемых файлов

cmd = 'dmd ' + " ".join( all_sources ) + ' -op -O -release -inline -noboundscheck'
#Запускаем компиляцию
import subprocess
PIPE = subprocess.PIPE
p = subprocess.Popen(cmd, shell=True, stdin=PIPE, stdout=PIPE,
        stderr=subprocess.STDOUT, close_fds=True, cwd = os.getcwd())
sys.stdout.write( p.stdout.read() )
