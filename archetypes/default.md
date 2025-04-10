---
author: 'csmyx'
date: '{{ .Date }}'
title: '{{ replace .File.ContentBaseName "-" " " | title }}  {{.File.ContentBaseName}}'
description: '{{ .File.Dir }}'
draft: false
ShowToc: true
TocOpen: true
ShowBreadCrumbs: false
# tags: ["Rust", "OS"]
# categories: ["Rust", "OS"]
series: ["{{ path.Dir .File.Path | path.Base }}"]
---
todo!