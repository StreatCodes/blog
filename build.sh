mkdir -p build/posts
cp -rv assets build

echo index.md
pandoc index.md -o build/index.html --template=template.html --standalone

for file in posts/*.md; do
  echo $file
  pandoc "$file" -o "build/${file%.md}.html" --template=template.html --standalone
done