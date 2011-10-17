#!/bin/bash
# скрипт для преобразования PDF и DJVU файлов в формат для эклектронной книги 800x600

# использование: скрипт документ -in_[pdf|djvu] -out_[pdf|djvu]

#TMP=/media/Data/1; export TMP
#TMPDIR=$TMP; export TMPDIR

in_format=$2
out_format=$3

mask="*.*"

if [ "$in_format" = "-in_djvu" ];
then
   # если это DJVU то приобразовываем его в многостраничный TIFF
   ddjvu -format=tiff $1 1.tiff
   # преобразовываем TIFF в набор JPG-файлов
   #convert -colorspace gray 1.tiff p%04d.jpg
   tiffsplit 1.tiff
   rm 1.tiff
   mask="x*.tif"
else
   # если это PDF то в набор JPG-файлов с выходным DPI = 150
   #convert -density 150 $1 p%04d.jpg
   pdftk $1 burst
   mask="pg_*.pdf"
fi

pages=""

# обработать все страницы
for p in `ls -1 $mask`; do

   # конвертируем страничку в JPG и преобразуем в оттенки серого
   if [ "$in_format" = "-in_djvu" ];
   then
      convert -colorspace gray -normalize -contrast $p $p.jpg
   else
      convert -density 300 -colorspace gray -normalize -contrast $p $p.jpg
   fi

   rm $p

   # назначем новое имя переменной
   p=${p}'.jpg'

   # если нужно отрезать калантитул
   #convert -gravity South -crop 100%x85% +repage $p $p

   # обрезаем все поля автоматически
   convert -trim +repage $p $p
   
   # вырезаем верхнюю часть картинки
   convert -gravity North -crop 100%x35% +repage $p 1_$p
   # вырезаем вторую часть картинки
   convert -gravity Center -crop 100%x35% +repage $p 2_$p
   # вырезаем третью часть картинки
   convert -gravity South -crop 100%x35% +repage $p 3_$p

   # удаляем страничку
   rm $p
   
   # меняем разрешение на 800х600
   convert -scale 800x600! 1_$p 1_$p
   convert -scale 800x600! 2_$p 2_$p
   convert -scale 800x600! 3_$p 3_$p
   
   # разворачиваем на 90 градусов
   convert -rotate 90 1_$p 1_$p
   convert -rotate 90 2_$p 2_$p
   convert -rotate 90 3_$p 3_$p
   
   # улучшаем качество картинки (резкость + нормализация)
   convert -sharpen 0.01 1_$p 1_$p #-normalize
   convert -sharpen 0.01 2_$p 2_$p #-normalize
   convert -sharpen 0.01 3_$p 3_$p #-normalize
   
   # если выходной файл DJVU
   if [ "$out_format" = "-out_djvu" ];
   then
      # конвертируем странички в djvu-формат
      c44 -dpi 150 1_$p 1_$p.djvu
      c44 -dpi 150 2_$p 2_$p.djvu
      c44 -dpi 150 3_$p 3_$p.djvu
	  
      # список страничек
      pages=${pages}' 1_'${p}'.djvu 2_'${p}'.djvu 3_'${p}'.djvu'
    else
      convert -define pdf:use-trimbox=true -density 200 1_$p 1_$p.pdf
      convert -define pdf:use-trimbox=true -density 200 2_$p 2_$p.pdf
      convert -define pdf:use-trimbox=true -density 200 3_$p 3_$p.pdf
      
      # список страничек
      pages=${pages}' 1_'${p}'.pdf 2_'${p}'.pdf 3_'${p}'.pdf'
    fi

    rm 1_$p 2_$p 3_$p
done

# создаем выходной файл книжки
if [ "$out_format" = "-out_djvu" ];
then
  # собрать в единый DjVu
  djvm -c out.djvu $pages
else
  # собрать в единый PDF
  #convert -adjoin $pages out.pdf
  pdftk $pages cat output out.pdf
fi

rm $pages
rm doc_data.txt


