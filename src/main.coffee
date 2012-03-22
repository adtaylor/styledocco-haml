# Dependencies
# ============

fs   = require 'fs'
path = require 'path'

mkdirp   = require 'mkdirp'
findit   = require 'findit'
jade     = require 'jade'
haml     = require 'ruby-haml'
optimist = require 'optimist'

langs  = require './languages'
parser = require './parser'
_ = require './utils'
express = require 'express'
server = require('./server')
server.start express, '/../../docs/'

# Configuration
# =============

options = optimist
  .usage('Usage: $0 [options] [INPUT]')
  .describe('name', 'Name of the project').alias('n', 'name').demand('name')
  .describe('out', 'Output directory').alias('o', 'out').default('out', 'docs')
  .describe('nocss', 'Hide CSS code pane').boolean('nocss').default('nocss', false)
  .describe('tmpl', 'Template directory').default('tmpl', "#{__dirname}/../resources/")
  .describe('overwrite', 'Overwrite existing files in target dir').boolean('overwrite')
  .describe('pass', 'Pass argument through to CSS preprocessor')
  .argv

options.in = options._[0] or './'

# Get sections of matching doc/code blocks.
getSections = (filename) ->
  data = fs.readFileSync filename, "utf-8"
  lang = langs.getLanguage filename
  if lang?
    blocks = parser.extractBlocks lang, data
    sections = parser.makeSections blocks
  else
    sections = parser.makeSections [ { docs: data, code: '' } ]
  sections


hamlify = (sections, cb) ->
  _len = sections.length - 1
  sections.forEach ( block, i )->
    if block.haml
      # code = block.haml.split 'FIXTURE:'
      # console.log block.haml.split 'FIXTURE:'
      # console.log '-----'
      # json = if code[1]? then JSON.parse(code[1]) else {}
      code = _.splitFixtures block.haml
      haml code.haml, code.json, (err, html)->
        if i is _len then cb(sections)
        if err then throw err
        block.docs = block.docs.replace('%HAML%', html);
    else
      if i is _len then cb(sections)

findFile = (dir, re) ->
  return null unless fs.statSync(dir).isDirectory()
  file = fs.readdirSync(dir).filter((file) -> file.match re)?[0]
  if file?
    path.join dir, file
  else
    null


# Generate the HTML document and write to file.
generateFile = (source, data) ->

  if source.match /readme/i
    source = 'index.html'
  dest = _.makeDestination source
  data.project = {
    name: options.name
    menu
    root: _.buildRootPath source
    nocss: options.nocss
  }

  render = (data) ->
    templateFile = path.join options.tmpl, 'docs.jade'
    template = fs.readFileSync templateFile, 'utf-8'
    html = jade.compile(template, filename: templateFile)(data)
    console.log "styledocco: #{source} -> #{path.join options.out, dest}"
    writeFile dest, html

  if langs.isSupported source
    # Run source through suitable CSS preprocessor.
    lang = langs.getLanguage source
    lang.compile source, options['pass'], (err, css) ->
      throw err if err?
      data.css = css
      render data
  else
    data.css = ''
    render data


# Write a file to the filesystem.
writeFile = (dest, contents) ->
  dest = path.join options.out, dest
  mkdirp.sync path.dirname dest
  fs.writeFileSync dest, contents


# Program flow starts here.
# =========================

# Make sure that specified output directory exists.
mkdirp.sync options.out

# Get all files from input (directory).
sources = findit.sync options.in

# Filter out unsupported file types.
files = sources.
  filter((source) ->
    return false if source.match /(\/|^)\./ # No hidden files.
    return false if source.match /(\/|^)_.*\.s[ac]ss$/ # No SASS partials.
    return false unless langs.isSupported source # Only supported file types.
    return false unless fs.statSync(source).isFile() # Files only.
    return true
  ).sort()

# Make `link` objects for the menu.
menu = {}
for file in files
  link =
    name: path.basename(file, path.extname file)
    href: _.makeDestination file
  parts = file.split('/').splice(1)
  key =
    if parts.length > 1
      parts[0]
    else
      './'
  if menu[key]?
    menu[key].push link
  else
    menu[key] = [ link ]

# Look for a README file and generate an index.html.
readme = findFile(options.in, /^readme/i) \
      or findFile(process.cwd(), /^readme/i) \
      or findFile(options.tmpl, /^readme/i)

sections = getSections readme

generateFile readme, { menu, sections, title: '', description: '' }

# Generate documentation files.
files.forEach (file) ->
  sections = getSections file
  sections = hamlify sections, (sects)->
    generateFile file, { menu, sections: sects, title: file, description: '' }

# Add default docs.css unless it already exists.
cssPath = path.join options.out, 'docs.css'
if options.overwrite or not path.existsSync cssPath
  fs.writeFileSync cssPath, fs.readFileSync path.join(options.tmpl, 'docs.css'), 'utf-8'
  console.log "styledocco: writing #{path.join options.out, 'docs.css'}"





