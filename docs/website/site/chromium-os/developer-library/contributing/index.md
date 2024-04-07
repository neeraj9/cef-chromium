---
breadcrumbs:
- - /chromium-os/developer-library
  - Chromium OS > Developer Library
page_name: contributing
title: Contributing
---

> 🚧 The library is currently under construction. See
> [the CrOS Developer Library Proposal](/chromium-os/developer-library/proposal)
> for more information.

Maintaining a well-curated developer library is a worthy goal which requires
the entire team to contribute. Thankfully modifying the CrOS Developer Library
is straightforward, and this guide will take you through the steps.

## Getting the library code

The library is hosted in the chromium.org website git repository hosted at
chromium.googlesource.com.

If you don't already have `depot_tools` cloned and in your `PATH`, see
[Get depot tools](https://commondatastorage.googleapis.com/chrome-infra-docs/flat/depot_tools/docs/html/depot_tools_tutorial.html#_setting_up).

```
$ git clone https://chromium.googlesource.com/website
$ gclient sync
```

## Website format

chromium.org is built using a static site generator,
[11ty](https://www.11ty.dev/). The website leverages 11ty's ability to render
Markdown as static HTML. 11ty supports Markdown Basic with inline HTML, though
the latter is generally discouraged to ensure consistent styling. Extended
Markdown like support for tables is not available.

11ty maps the directory structure of the source code to the website URLs. As an
example, the git source directory of the Developer Library is
`website/site/chromium-os/developer-library`, and this maps to the URL
`chromium.org/chromium-os/developer-library`. The content of each page is in a
file named `index.md` within the directory whose name matches the page.

## Adding a new page

Once you have the website source code, you are able to add a new page (document)
to the library.

### Determining the right library location

The developer library is organized into four main sections: Getting Started,
Guides, Reference, and Training. The Getting Started guide is a multipage book,
while the other sections are flat indexes grouped by topic. To make sure your
new content is easy to find, pick the most appropriate location and topic for
your new page.

<table>
  <thead>
    <tr>
      <th scope="col">Section</th>
      <th scope="col">Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th scope="row">Getting Started</th>
      <td>A multipage guide to bootstrap the development process</td>
    </tr>
    <tr>
      <th scope="row">Guides</th>
      <td>Step-by-step instructions for accomplishing tasks</td>
    </tr>
    <tr>
      <th scope="row">Reference</th>
      <td>Educational descriptions of tools, processes, and infrastructure</td>
    </tr>
    <tr>
      <th scope="row">Training</th>
      <td>Person-oriented training material like videos and codelabs</td>
    </tr>
  </tbody>
</table>

### Adding the page directory and index.md

To give an example of a new page to add to the Guides section of the library
whose URL is `chromium.org/chromium-os/developer-library/guides/code-coverage`,
create the new source folder named code-coverage and Markdown file index.md:

```
website$ mkdir chromium-os/developer-library/guides/code-coverage
website$ touch chromium-os/developer-library/guides/code-coverage/index.md
```

### Writing the page metadata

At the top of each page in the library, breadcrumb links are rendered to allow
easy navigation. This content is rendered from the metadata section at the top
of each Markdown file. Here is the metadata for our example new page:

```
---
breadcrumbs:
- - /chromium-os/developer-library/guides
  - Chromium OS > Developer Library > Guides
page_name: code-coverage
title: Code Coverage
---
```

The `breadcrumbs` section has two entries: the first is the URL of the
breadcrumb link, and the second is the text rendered in the link. The
`page_name` variable should match the name of the directory containing this
Markdown file. The `title` variable is the title of the rendered webpage.

### Creating content

You're now ready to create the content of the new library page. Please consider
technical writing best practices by writing to the intended audience, succinctly
providing necessary context, and being to-the-point.

## Testing the change

chromium.org leverages Node Package Manager to build the website. The `npmw`
command enables you to locally build and view the website from source.

```
website$ npmw build
website$ npmw start
```

Assuming the build is successful, the `start` command displays the local URL you
can browse to in order to see the locally built website.

```
[Browsersync] Access URLs:
 --------------------------------------
       Local: http://localhost:8080
    External: <redacted>
 --------------------------------------
          UI: http://localhost:3001
 UI External: http://localhost:3001
```

The website is available at the `Local` URL.

`npmw start` provides a real-time build/redeploy development cycle, i.e., once
the command is running, it listens for filesystem changes to the source code,
rebuilds, and reloads the served website instance.

## Committing the change

Once the content is created, commit the change per the regular git workflow.
Please craft a thoughtful commit message which describes the change.

```
website$ git add site/chromium-os/developer-library/guides/code-coverage
website$ git commit -a
```

## Uploading the change for review

When you are ready to send your change for review, use `git cl upload` to upload
the change to [gerrit](https://chromium-review.googlesource.com/). Add
`jhawkins@chromium.org` as a reviewer.

```
website$ git cl upload -r jhawkins@chromium.org
```

After review and editing, the change can be submitted in gerrit.