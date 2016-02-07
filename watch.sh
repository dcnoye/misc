#!/bin/bash
#D.C. Noye 2015
#TODO add cpu percent with awk from top
watch "ps -e h -o pid --sort -pcpu | head -50 | vzpid -"
