---
author: 'csmyx'
date: '{{ .Date }}'
disableShare: true
title: '{{ replace .File.ContentBaseName "-" " " }}'
# description: '{{ replace .File.ContentBaseName "-" " " | title }}'
summary: '{{ replace .File.ContentBaseName "-" " " }}'
# tags: ["Rust", "OS"]
# categories: ["Rust", "OS"]
series: ["{{ path.Dir .File.Path | path.Base }}"]
---
todo!