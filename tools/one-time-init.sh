#!/bin/sh
cd ..
git clone https://github.com/yast/yast-meta
export PATH=$PWD/yast-meta:$PATH
mkdir yast-checkout
cd ../yast-checkout
y2m clone ALL
cd ..
git init yast-translations
svn checkout https://svn.opensuse.org/svn/opensuse-i18n/trunk/yast/ yast-lcn
