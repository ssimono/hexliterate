#! /bin/sh

env | sed -n '/^WSD_/p' | while read envvar
do
  name=$(echo $envvar | cut -d '=' -f 1 | sed 's/^WSD_//;s/_/-/g' | tr [:upper:] [:lower:])
  value=$(echo $envvar | cut -d '=' -f 2-)
  echo -n "--$name=$value "
done
