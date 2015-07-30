#!/bin/bash
#TODO add cpu percent with awk from top
watch "ps -e h -o pid --sort -pcpu | head -50 | vzpid -"
