# nodi

[![Package Version](https://img.shields.io/hexpm/v/nodi)](https://hex.pm/packages/nodi)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/nodi/)

A very simple templating library for gleam that will help you
turn `.nodi` files into `.gleam` ones. Nodi uses a similar
format to html but includes a frontmatter with metadata and
a body to include slot references.

## Quick example

```html
<!-- example.nodi -->
req=wibble
---
<div>
  <% wibble %>
</div>
```
Turns into:

```gleam
// example.gleam
pub type Example {
  Example(wibble: String)
}

pub fn new(wibble: String) -> Example {
  Example(wibble:)
}

pub fn to_string(example: Example) -> String {
  "
<div>
  " <> example.wibble <> "
</div>"
}
```

## Installation
Nodi is currently in development and not available through Hex. If you want to add it to your project through `gleam.toml` as a dependency:

```toml
[dependencies]
nodi = { git = "https://github.com/CristianRos/nodi.git", ref = "main" }
```
Setup your IDE to handle `.nodi` files as if they where `.html` ones and you are ready to go!

## Use cases
Right now Nodi doesn't try to be more than a toy templating language (specifically made because I wanted to tinker with Datastar and Gleam). But it's based entirely in Strings so you can declare slots at any place into your `.nodi` file.

This can be used to generate _static html_ and reusable _html_ pieces through your codebase that can be composed together.

I will be populating an `examples/` folder with anything that I find useful working with this tool.

## Why the `.nodi` extension?
The `.nodi` extension allows buy in into future tooling or modifications to the spec without having breaking changes by moving from `.html` into `.nodi`.

## How Nodi works?
Nodi is basically an _html_ file with a frontmatter.

A separator `---` that divides the file into _Metadata_ (top side) and _Body_ (bottom side).

### The metadata is formed by Declarations.

`req=foo`: This is a _Required_ declaration with a _foo_ slot. This slot _MUST_ be referenced in the body.

`opt=bar`: This is an _Optional_ declaration with a _bar_ slot. This slot _CAN_ be referenced in the body but it's not mandatory.

### The body is formed by Text and SlotReferences

Either you have _HTML_ that will be turned into a text String, or you are referencing a slot through a tag like:
`<% foo %>` that will also be turned into a String by the content you filled in through the `.gleam` component.

Optional slot references that aren't fulfilled will be turned into an empty string.


### If a Nodi template contains no slots
Then a String constant will be generated instead as pure static _HTML_.

```html
<div>
  <p>This is fully static</p>
</div>
```

```gleam
pub const generated = "<div>
  <p>This is fully static</p>
</div>"
```

## Attribution
Nodi takes inspiration from and includes code derived from 
[squirrel](https://github.com/giacomocavalieri/squirrel) by Giacomo Cavalieri, which is an amazing project I learned a lot and still am!

Squirrel is licensed under the Apache License 2.0.

