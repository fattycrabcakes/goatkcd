package GoatKCD::Extractor;
use strict;

our $VERSION = '6.6.6';

use Inline Python => <<'END_OF_PYTHON_CODE';

import cv2;
import sys;
import numpy;
import json

def vertical(x1,y1,x2,y2):
 if (x2==x1):
  return True
 return False
def horizontal(x1,y1,x2,y2):
 if (y2==y1):
  return True
 return False
def byX(item):
 return item[0]
def byY(item):
 return item[3]
def intersect(line1,line2):
 if (line2[0]>=line[0] and line2[2]<=line[2]) and (line2[1]<=line[1] and line2[3]>=line[3]):
  return True
 return False

def areas(path):
 img = cv2.imread(path)
 height,width,depth = img.shape
 gray = cv2.cvtColor(img,cv2.COLOR_BGR2GRAY)
 edges = cv2.Canny(gray,20,255,apertureSize = 3)
 if (height>width):
  minLineLength = int(height/5)
 else:
  minLineLength = int(width/5)
 if (minLineLength> height):
  minLineLength = height*0.75;
 maxLineGap = 25

 
 lines = map(lambda x: [int(x[0]),int(x[3]),int(x[2]),int(x[1])], cv2.HoughLinesP(edges,1,numpy.pi/180,int(minLineLength),minLineLength,maxLineGap)[0]) 
 minX = min(lines,key=byX)[0]
 maxX = max(lines,key=byX)[0]
 minY = min(lines,key=byY)[1]
 maxY = max(lines,key=byY)[1]
 
 lastPoint = 0
 filtered=[]
 hor_lines=[]
 ver_lines=[]
 
 for point in sorted(filter(lambda x: x[0]==x[2],lines), key=byX):
  if (point[0]-lastPoint>=3):
   point[1]=minY
   point[3]=maxY
   ver_lines.append(point)
  lastPoint=point[0]
 
 lastPoint=0
 for point in sorted(filter(lambda x: x[1]==x[3],lines), key=byY):
  if (point[1]-lastPoint>=3):
   point[0]=minX
   point[2]=maxX
   hor_lines.append(point)
  lastPoint=point[1]
 
 i=0;
 row=0;
 rectangles = [];
 while (i<len(hor_lines)-1):
  top = hor_lines[i];
  bottom = hor_lines[i+1]
  j=0
  while (j<len(ver_lines)-1):
   left=ver_lines[j]
   right=ver_lines[j+1]
   j=j+1
   if (bottom[1]-top[1]> 15 and right[0]-left[0]>15):
    rectangles.append([left[0],top[1],right[0],bottom[1]]);
  i=i+1
  row = row+1
 
 row_offsets = sorted(list(set(map(lambda y: y[1],rectangles))))
 rows = [];
 for offset in row_offsets:
  rows.append(filter(lambda y: y[1]==offset,rectangles))
 
 return rows;


END_OF_PYTHON_CODE
1;
