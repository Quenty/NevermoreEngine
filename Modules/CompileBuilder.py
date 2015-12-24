import os

# Writes files to ModuleList.txt for easy installation
# Author: Quenty

# Outputs a line delimited file with folders delimited by \ and the last string
# the name of the file

fileList = ''

for (root, dirNames, fileNames) in os.walk("."):
    for fileName in fileNames:
        if fileName.endswith('.lua'):
            #fileName = fileName[:-4]
            fileList += os.path.join(root[2:], fileName) + '\n'

print(fileList)

f = open('ModuleList.txt', 'w+')
f.write(fileList)
f.close()

print("Wrote file list")