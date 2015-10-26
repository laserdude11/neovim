-- ShaDa history saving/reading support
local helpers = require('test.functional.helpers')
local nvim_command, funcs, meths, nvim_feed, eq =
  helpers.command, helpers.funcs, helpers.meths, helpers.feed, helpers.eq

local shada_helpers = require('test.functional.shada.helpers')
local reset, set_additional_cmd, clear =
  shada_helpers.reset, shada_helpers.set_additional_cmd,
  shada_helpers.clear

describe('ShaDa support code', function()
  before_each(reset)
  after_each(clear)

  it('is able to dump and read back command-line history', function()
    nvim_command('set shada=\'0')
    nvim_feed(':" Test\n')
    nvim_command('wshada')
    reset()
    nvim_command('set shada=\'0')
    nvim_command('rshada')
    eq('" Test', funcs.histget(':', -1))
  end)

  it('is able to dump and read back 2 items in command-line history', function()
    nvim_command('set shada=\'0 history=2')
    nvim_feed(':" Test\n')
    nvim_feed(':" Test 2\n')
    nvim_command('qall')
    reset()
    nvim_command('set shada=\'0 history=2')
    nvim_command('rshada')
    eq('" Test 2', funcs.histget(':', -1))
    eq('" Test', funcs.histget(':', -2))
    nvim_command('qall')
  end)

  it('respects &history when dumping',
  function()
    nvim_command('set shada=\'0 history=1')
    nvim_feed(':" Test\n')
    nvim_feed(':" Test 2\n')
    nvim_command('wshada')
    reset()
    nvim_command('set shada=\'0 history=2')
    nvim_command('rshada')
    eq('" Test 2', funcs.histget(':', -1))
    eq('', funcs.histget(':', -2))
  end)

  it('respects &history when loading',
  function()
    nvim_command('set shada=\'0 history=2')
    nvim_feed(':" Test\n')
    nvim_feed(':" Test 2\n')
    nvim_command('wshada')
    reset()
    nvim_command('set shada=\'0 history=1')
    nvim_command('rshada')
    eq('" Test 2', funcs.histget(':', -1))
    eq('', funcs.histget(':', -2))
  end)

  it('dumps only requested amount of command-line history items', function()
    nvim_command('set shada=\'0,:1')
    nvim_feed(':" Test\n')
    nvim_feed(':" Test 2\n')
    nvim_command('wshada')
    -- Regression test: :wshada should not alter or free history.
    eq('" Test 2', funcs.histget(':', -1))
    eq('" Test', funcs.histget(':', -2))
    reset()
    nvim_command('set shada=\'0')
    nvim_command('rshada')
    eq('" Test 2', funcs.histget(':', -1))
    eq('', funcs.histget(':', -2))
  end)

  it('does not respect number in &shada when loading history', function()
    nvim_command('set shada=\'0')
    nvim_feed(':" Test\n')
    nvim_feed(':" Test 2\n')
    nvim_command('wshada')
    reset()
    nvim_command('set shada=\'0,:1')
    nvim_command('rshada')
    eq('" Test 2', funcs.histget(':', -1))
    eq('" Test', funcs.histget(':', -2))
  end)

  it('dumps and loads all kinds of histories', function()
    nvim_command('debuggreedy')
    nvim_feed(':debug echo "Test"\n" Test 2\nc\n')  -- Debug history.
    nvim_feed(':call input("")\nTest 2\n')  -- Input history.
    nvim_feed('"="Test"\nyy')  -- Expression history.
    nvim_feed('/Test\n')  -- Search history
    nvim_feed(':" Test\n')  -- Command-line history
    nvim_command('0debuggreedy')
    nvim_command('wshada')
    reset()
    nvim_command('rshada')
    eq('" Test', funcs.histget(':', -1))
    eq('Test', funcs.histget('/', -1))
    eq('"Test"', funcs.histget('=', -1))
    eq('Test 2', funcs.histget('@', -1))
    eq('c', funcs.histget('>', -1))
  end)

  it('dumps and loads last search pattern with offset', function()
    funcs.setline('.', {'foo', 'bar'})
    nvim_feed('gg0/a/e+1\n')
    eq({0, 2, 3, 0}, funcs.getpos('.'))
    nvim_command('wshada')
    reset()
    funcs.setline('.', {'foo', 'bar'})
    nvim_feed('gg0n')
    eq({0, 2, 3, 0}, funcs.getpos('.'))
  end)

  it('saves v:hlsearch=1', function()
    nvim_command('set hlsearch shada-=h')
    nvim_feed('/test\n')
    eq(1, meths.get_vvar('hlsearch'))
    nvim_command('qall')
    reset()
    eq(1, meths.get_vvar('hlsearch'))
  end)

  it('saves v:hlsearch=0 with :nohl', function()
    nvim_command('set hlsearch shada-=h')
    nvim_feed('/test\n')
    nvim_command('nohlsearch')
    nvim_command('qall')
    reset()
    eq(0, meths.get_vvar('hlsearch'))
  end)

  it('saves v:hlsearch=0 with default &shada', function()
    nvim_command('set hlsearch')
    nvim_feed('/test\n')
    eq(1, meths.get_vvar('hlsearch'))
    nvim_command('qall')
    reset()
    eq(0, meths.get_vvar('hlsearch'))
  end)

  it('dumps and loads last substitute pattern and replacement string', function()
    funcs.setline('.', {'foo', 'bar'})
    nvim_command('%s/f/g/g')
    eq('goo', funcs.getline(1))
    nvim_command('wshada')
    reset()
    funcs.setline('.', {'foo', 'bar'})
    nvim_command('&')
    eq('goo', funcs.getline(1))
  end)

  it('dumps and loads history correctly when &encoding is not UTF-8', function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim_feed(':echo "\171"\n')
    nvim_command('qall')
    reset()
    eq('echo "\171"', funcs.histget(':', -1))
  end)

  it('dumps and loads history correctly when &encoding /= UTF-8 when dumping',
  function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim_feed(':echo "\171"\n')
    set_additional_cmd('')
    nvim_command('qall')
    reset()
    eq('echo "«"', funcs.histget(':', -1))
  end)

  it('dumps and loads history correctly when &encoding /= UTF-8 when loading',
  function()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim_feed(':echo "«"\n')
    set_additional_cmd('set encoding=latin1')
    nvim_command('qall')
    reset()
    eq('echo "\171"', funcs.histget(':', -1))
  end)

  it('dumps and loads replacement correctly when &encoding is not UTF-8',
  function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim_command('substitute/./\171/ge')
    nvim_command('qall!')
    reset()
    funcs.setline('.', {'.'})
    nvim_command('&')
    eq('\171', funcs.getline('.'))
  end)

  it('dumps&loads replacement correctly when &encoding /= UTF-8 when dumping',
  function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim_command('substitute/./\171/ge')
    set_additional_cmd('')
    nvim_command('qall')
    reset()
    funcs.setline('.', {'.'})
    nvim_command('&')
    eq('«', funcs.getline('.'))
  end)

  it('dumps&loads replacement correctly when &encoding /= UTF-8 when loading',
  function()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim_command('substitute/./«/ge')
    set_additional_cmd('set encoding=latin1')
    nvim_command('qall')
    reset()
    funcs.setline('.', {'.'})
    nvim_command('&')
    eq('\171', funcs.getline('.'))
  end)

  it('dumps and loads substitute pattern correctly when &encoding is not UTF-8',
  function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim_command('substitute/\171/./ge')
    nvim_command('qall!')
    reset()
    funcs.setline('.', {'\171«'})
    nvim_command('&')
    eq('.«', funcs.getline('.'))
  end)

  it('dumps&loads s/pattern correctly when &encoding /= UTF-8 when dumping',
  function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim_command('substitute/\171/./ge')
    set_additional_cmd('')
    nvim_command('qall')
    reset()
    funcs.setline('.', {'«\171'})
    nvim_command('&')
    eq('.\171', funcs.getline('.'))
  end)

  it('dumps&loads s/pattern correctly when &encoding /= UTF-8 when loading',
  function()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim_command('substitute/«/./ge')
    set_additional_cmd('set encoding=latin1')
    nvim_command('qall')
    reset()
    funcs.setline('.', {'\171«'})
    nvim_command('&')
    eq('.«', funcs.getline('.'))
  end)

  it('dumps and loads search pattern correctly when &encoding is not UTF-8',
  function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim_command('silent! /\171/')
    nvim_command('set shada+=/0')
    nvim_command('qall!')
    reset()
    funcs.setline('.', {'\171«'})
    nvim_command('~&')
    eq('«', funcs.getline('.'))
    eq('', funcs.histget('/', -1))
  end)

  it('dumps&loads /pattern correctly when &encoding /= UTF-8 when dumping',
  function()
    set_additional_cmd('set encoding=latin1')
    reset()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim_command('silent! /\171/')
    nvim_command('set shada+=/0')
    set_additional_cmd('')
    nvim_command('qall')
    reset()
    funcs.setline('.', {'«\171'})
    nvim_command('~&')
    eq('\171', funcs.getline('.'))
    eq('', funcs.histget('/', -1))
  end)

  it('dumps&loads /pattern correctly when &encoding /= UTF-8 when loading',
  function()
    -- \171 is U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK in latin1
    nvim_command('silent! /«/')
    nvim_command('set shada+=/0')
    set_additional_cmd('set encoding=latin1')
    nvim_command('qall')
    reset()
    funcs.setline('.', {'\171«'})
    nvim_command('~&')
    eq('«', funcs.getline('.'))
    eq('', funcs.histget('/', -1))
  end)
end)
