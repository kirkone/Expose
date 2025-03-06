# Exposé

Exposé is a Bash script that helps photographers generate a stylish website to showcase their images. The result is a static website that focuses on displaying the images without any gimmicks like JavaScript.

Here are some examples of websites that use this script:
- https://kirkone.github.io/Expose/ (current example site)
- https://photo.kirk.one/ (my personal website)

## Features

- **Easy to Use**: Just a Bash script, no additional dependencies.
- **Static Website**: No need for a web server or dynamic content.
- **Stylish Presentation**: Focus on the images without distracting elements.
- **Automatic Generation**: Automatically generates HTML files based on the images in a folder.

## Requirements

- Unix-based operating systems (Linux, macOS)
- Bash
- ImageMagick
- FFmpeg

## Basic usage

```sh
expose.sh -p example.site
```
The script operates on your current working directory, and outputs a `output` directory.

### Configuration

Site title, theme, jpeg quality and other config values can be edited in `config.sh` in the top
level of your project, eg:

```sh
site_title="Alternate Site Title"
theme="theme2"
social_button=false
backgroundcolor="#ffffff"
```

### Flags

```
expose.sh -p example.site
```

The -p flag privides the name of the project folder that should be processed. Defaults to the first folder in the `./projects` folder.

```
expose.sh -d
```

The -d flag enables draft mode, where only a single low resolution is encoded. This can be used for a quick preview or for layout purposes.

Generated images are not overwritten, to do a completely clean build delete the existing output directory first.

## Adding text

The text associated with each image is read from any text file with the same filename as the image, eg:

## Sorting

Images are sorted by reverse alphabetical order. To arbitrarily order images, add a numerical prefix

## Organization

You can put images in folders to organize them. The folders can be nested any number of times, and are also sorted alphabetically. The folder structure is used to generate a nested html menu.

To arbitrarily order folders, add a numerical prefix to the folder name. Any numerical prefixes are stripped from the url.

Any folders or images with an "_" prefix are ignored and excluded from the build.

## Metadata file

If you want certain variables to apply to an entire gallery, place a metadata.txt (this is configurable) file in the project directory. eg. in metadata.txt:

	width: 19

This sets all image widths to form a grid. Metadata file parameters are overriden by metadata in individual posts.

## Advanced usage

### Templating

If the two built-in themes aren't your thing, you can create a new theme. There are only two template files in a theme:

**template.html** contains the global html for your page. It has access to the following built-in variables:

- `{{basepath}}` - a path to the top level directory of the generated site with trailing slash, relative to the current html file
- `{{resourcepath}}` - a path to the gallery resource directory, relative to the current html file. This will be mostly empty (since the html page is in the resource directory), except for the top level index.html file, which necessarily draws resources from a subdirectory
- `{{resolution}}` - a list of horizontal resolutions, as specified in the config. This is a single string with space-delimited values
- `{{content}}` - where the text/images will go
- `{{sitetitle}}` - a global title for your site, as specified in the config
- `{{site_copyright}}` - a copyright for your site, as specified in the config
- `{{gallerytitle}}` - the title of the current gallery. This is just taken from the folder name
- `{{navigation}}` - a nested html menu generated from the folder structure. Does not include wrapping ul tag so you can use your own id

**post-template.html** contains the html fragment for each individual image. It has access to the following built-in variables:

- `{{imageurl}}` - url of the *directory* which contains the image resources, relative to the current html file.
	- For images, this folder will contain all the scaled versions of the images, where the file name is simply the width of the image - eg. 640.jpg
- `{{imagewidth}}` - maximum width that the source image can be downscaled to
- `{{imageheight}}` - maximum height, based on aspect ratio and max width
- `{{textcolor}}` - color of the text, either extracted from the source image or specified in config
- `{{backgroundcolor}}` - background color, either extracted from the source image or specified in config

in addition to these, any variables specified in the YAML metadata of the post will also be available to the post template, eg:

	---
	mycustomvar: foo
	---

this will cause {{mycustomvar}} to be replaced by "foo", in this particular post

#### Additional notes:

Specify default values, in case of unset template variables in the form {{foo:bar}} eg:

	{{width:50}}

will set width to 50 if no specific value has been assigned to it by the time page generation has finished.

Any unused {{xxx}} variables that did not have defaults are removed from the generated page.

Any non-template files (css, images, javascript) in the theme directory are simply copied into the output directory.

To avoid additional dependencies, the YAML parser and template engine is simply a sed regex. This means that YAML metadata must take the form of simple key:value pairs, and more complex liquid template syntax are not available.

## License

This project is licensed under the MIT License. For more information, see the LICENSE file.