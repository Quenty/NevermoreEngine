import os
import fnmatch

# Writes files to ModuleList.txt for easy installation

# Outputs a line delimited file with folders delimited by \ and the last string
# the name of the file

fileList = ''
ignoreFiles = ['AxisCameraEngine.lua', 'AccelTween.lua']

for (root, dirNames, fileNames) in os.walk("."):
    newFileNames = fileNames

    for ignoreName in ignoreFiles:
        newFileNames = [fileName for fileName in newFileNames if not fnmatch.fnmatch(fileName, ignoreName)]

    for fileName in [fileName for fileName in newFileNames if fileName.endswith('.lua')]:
        fileList += os.path.join(root[2:], fileName) + '\n'

print(fileList)

f = open('ModuleList.txt', 'w+')
f.write(fileList)
f.close()

print("Wrote file list.")
input()