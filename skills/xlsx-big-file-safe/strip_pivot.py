#!/usr/bin/env python3
"""Убрать сводные таблицы и их кэш из xlsx: strip_pivot.py in.xlsx out.xlsx"""
import re, sys, zipfile
src, dst = sys.argv[1:3]
with zipfile.ZipFile(src) as zi, zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zo:
    for i in zi.infolist():
        n = i.filename
        if n.startswith(("xl/pivotCache/", "xl/pivotTables/")):
            continue
        data = zi.read(n)
        if n.endswith((".rels", "workbook.xml", "[Content_Types].xml")):
            s = data.decode("utf-8")
            s = re.sub(r"<Relationship [^>]*pivot[^>]*/>", "", s)
            s = re.sub(r"<Override [^>]*pivot[^>]*/>", "", s)
            s = re.sub(r"<pivotCaches>.*?</pivotCaches>", "", s, flags=re.S)
            data = s.encode("utf-8")
        zo.writestr(i, data)
