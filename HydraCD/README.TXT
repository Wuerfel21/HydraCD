Main README.TXT file for "Game Programming for the Propeller Powered HYDRA"
by Andre' LaMothe

Root Directory.

-------------------------------------------------------------------

License Agreement

CD-ROM and software copyright (C) 2006 Parallax Inc., Nurve Networks LLC,
Andre' LaMothe. All rights reserved. Individual programs are copyrighted 
by their respective owners and may require separate licensing. This CD-ROM may 
not be redistributed without prior written permission from the publisher. 
The right to redistribute the individual programs on the CD-ROM depends on 
each program's license. Consult each program for details.

Publisher Website

    http://www.parallax.com

Publisher Support

    support@parallax.com

Author Email
ceo@nurve.net
www.xgamestation.com

-------------------------------------------------------------------

Table of Contents:

I.   INTRODUCTION
II.  INSTALLING THE CONTENT FROM THE CD
III. INSTALLING THE TOOLS
IV.  PROBLEMS YOU MIGHT ENCOUNTER (PLEASE READ!!!!!!)
V.   COMPATIBILITY.
VI.  BONUS MATERIAL - The Black Art of 3D Game Programming.
VII. ERRATA

I. INTRODUCTION

   Welcome to "Game Programming for the Propeller Powered HYDRA". This CD is all 
   you need to get started with the book and understanding the HYDRA game console
   programming and development. 

   The first thing you might notice is that isn't any kind of main installation
   program on the CD. I have found that 9 out of 10 times the best installer is
   the user since only he/she knows what and where to install things, so I'm
   going to leave the actual file copying and installation to you. However, 
   within each directory there is a README.TXT file that explains what the files 
   are and what they are for. The CD is set up like this:

    CD_ROOT:\
        | 
        HYDRA\
            |
            \SOURCES\
            \DESIGNS\
            \DRIVERS\
            \DEMOS\
            \TOOLS\
            \MEDIA\
            \DOCS\
            \EBOOKS\
            \GOODIES\
            README.TXT
            license.txt
     
    The contents of each of the directories is are follows:

    HYDRA\   - This is the main root directory of the entire CD, everything is 
               within this directory, thus to copy the entire CD, simply right 
               click on this directory, "copy" and then you can paste it anywhere 
               you like on your hard drive, I suggest placing it at the root of
               C:\ so the paths are short to the files within.
               
    DESIGNS\ - This directory contains electronic design schematics.

    SOURCES\ - This directory is the source directory that contains the entire source for the book.

    DRIVERS\ - This directory contains any 3rd party drivers for the HYDRA and/or Propeller chip.

    DEMOS\   - This directory contains copies all the HYDRA demos as well as any other demos from 
               the book. Some of this data is copied from the SOURCES\ directory, but is copied 
               here to find more directly if you want to play with demos.
    
    MEDIA\   - This directory contains stock media and assets you can use for your game and 
               graphics development. All the media is royalty free and can be used for anything 
               you wish, even in commercial applications. However, you can not license, sell, or 
               otherwise transfer the files in the MEDIA\ directory as a product.

    DOCS\    - This directory contains documents, tutorials, articles all relating the HYDRA, 
               Propeller chip, and game development.

    EBOOKS\  - In this directory you will find complete eBooks. Included specifically with the HYDRA is 
               "The Black Art of 3D Game Programming" which can be used as a companion guide to this book 
               for more advanced DOS game programming techniques and PC development that are similar to 
               working with the HYDR - a $60 value!

    GOODIES\ -  This directory contains all kinds of cool little extras, so check it out and see what 
                made it on the CD!

    README.TXT  This is the README.TXT file for the CD, please read it carefully it has many last minute 
                changes, errata, and anything else you need to know.

   
II. INSTALLING THE CONTENT / SOURCE CODE FROM THE BOOK

     The source code and data for each chapter of this book are contained
     within the HYDRA\ sub-directory. I suggest simply copying the entire
     directory as-is onto your hard drive by "dragging" it from
     the CD or by using XCOPY or other similar technique. You may
     need to unzip the contents of each directory, if so make sure to
     enable directories.
     
III. INSTALLING THE APPLICATIONS AND TOOLS

     There are a number of applications and tools that are contained on this
     CD such as the Propeller IDE, and various media tools. Take a look at the 
     README.TXT file for each application for details.

IV. PROBLEMS YOU MIGHT ENCOUNTER

     * Read Only Flag *

     This is a very important detail, so read on. When creating a CD ROM disk
     all the files will be written with the READ-ONLY flag enabled. This is 
     fine in most cases unless you copy the files to your hard drive (which you will)
     and then edit and try to write the files back to disk. You will get a 
     READ-ONLY protection error. 

     Fixing this is a snap. You simply need to clear the READ-ONLY flag on any 
     files that you want to modify. There are 3 ways to do it. First, you can 
     do it with Windows and simply navigate into the directory with the file 
     you want to clear the READ-ONLY flag and then select the file, press 
     the RIGHT mouse button to get the file properties and then clear the 
     READ-ONLY flag and APPLY you change. You can do this will more than one 
     file at once by selecting a group of files.

     The second way is to use the File Manager and perform a similar set of 
     operations as in the example above. The third and best way is to the DOS 
     ATTRIB command with a DOS/Command Shell prompt. Here's how: 

     Assume you have copied the entire SOURCE directory on your hard drive to the 
     location C:\HYDRA. To reset all the READ-ONLY attributes in one fell 
     swoop you can use the ATTRIB command. Here is the syntax:
    
     C:\HYDRA> ATTRIB -r *.* /s

     This instructs the command shell to clear the READ-ONLY flag "r" from all 
     files "*.*" and all lower sub-directories "/s".
                       

V. COMPATIBILITY

     The contents of this CD/book were tested on Windows XP/2000/2003 Pentium III, 
     IV, and equivalent AMD processors. 

VI. BONUS MATERIAL - The Black Art of 3D Game Programming.

     As a BONUS, we have included an eBook version of the original groundbreaking 3D tome
     "The Black Art of 3D Game Programming". Released over a decade ago, it was the bible for 
     many 3D game programmers and covered such topics as binary space partitions and voxel graphics.
     You will find the eBook PDF as well as source code in the directory BONUS_BA3DBOOK\ -- enjoy!

VII. ERRATA

    None.


VERSION 1.0

