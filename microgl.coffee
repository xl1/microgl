glproto = WebGLRenderingContext.prototype

TYPESUFFIX = {}
TYPESUFFIX[glproto.FLOAT]        = '1f'
TYPESUFFIX[glproto.FLOAT_VEC2]   = '2fv'
TYPESUFFIX[glproto.FLOAT_VEC3]   = '3fv'
TYPESUFFIX[glproto.FLOAT_VEC4]   = '4fv'
TYPESUFFIX[glproto.INT]          = '1i'
TYPESUFFIX[glproto.INT_VEC2]     = '2iv'
TYPESUFFIX[glproto.INT_VEC3]     = '3iv'
TYPESUFFIX[glproto.INT_VEC4]     = '4iv'
TYPESUFFIX[glproto.FLOAT_MAT2]   = 'Matrix2fv'
TYPESUFFIX[glproto.FLOAT_MAT3]   = 'Matrix3fv'
TYPESUFFIX[glproto.FLOAT_MAT4]   = 'Matrix4fv'
TYPESUFFIX[glproto.SAMPLER_2D]   = 'Sampler2D'
TYPESUFFIX[glproto.SAMPLER_CUBE] = 'SamplerCube'

TYPESIZE = {}
TYPESIZE[glproto.FLOAT]      = 1
TYPESIZE[glproto.FLOAT_VEC2] = 2
TYPESIZE[glproto.FLOAT_VEC3] = 3
TYPESIZE[glproto.FLOAT_VEC4] = 4
TYPESIZE[glproto.FLOAT_MAT2] = 4
TYPESIZE[glproto.FLOAT_MAT3] = 9
TYPESIZE[glproto.FLOAT_MAT4] = 16


class MicroGL
  constructor: (opt) ->
    c = document.createElement('canvas')
    @gl = c.getContext('webgl', opt) or c.getContext('experimental-webgl', opt)
    @enabled = !!@gl
    return if not @gl
    @uniforms = {}
    @attributes = {}
    @textures = {}


  init: (elem, width=256, height=256) ->
    @width = @gl.canvas.width = width
    @height = @gl.canvas.height = height
    elem?.appendChild(@gl.canvas)
    @gl.viewport(0, 0, width, height)
    @gl.clearColor(0, 0, 0, 1)
    @gl.clearDepth(1)
    @gl.enable(@gl.DEPTH_TEST)
    @gl.depthFunc(@gl.LEQUAL)
    @


  makeProgram: (vsSource, fsSource) ->
    initShader = (type, source) =>
      shader = @gl.createShader(type)
      @gl.shaderSource(shader, source)
      @gl.compileShader(shader)
      if not @gl.getShaderParameter(shader, @gl.COMPILE_STATUS)
        console.log(@gl.getShaderInfoLog(shader))
      @gl.attachShader(program, shader)

    program = @gl.createProgram()
    initShader(@gl.VERTEX_SHADER, vsSource)
    initShader(@gl.FRAGMENT_SHADER, fsSource)

    @gl.linkProgram(program)
    if not @gl.getProgramParameter(program, @gl.LINK_STATUS)
      console.log(@gl.getProgramInfoLog(program))
    else
      program


  program: (vsSource, fsSource) ->
    # param: (vsSource, fsSource) or (program)
    program = if fsSource then @makeProgram(vsSource, fsSource) else vsSource
    @uniforms = {}
    @attributes = {}
    @_useElementArray = false
    @_texnum = 0

    @gl.useProgram(program)
    for i in [0...@gl.getProgramParameter(program, @gl.ACTIVE_UNIFORMS)]
      uniform = @gl.getActiveUniform(program, i)
      @uniforms[uniform.name] = {
        location: @gl.getUniformLocation(program, uniform.name)
        type: uniform.type
        size: uniform.size # array length
      }
    for i in [0...@gl.getProgramParameter(program, @gl.ACTIVE_ATTRIBUTES)]
      attribute = @gl.getActiveAttrib(program, i)
      loc = @gl.getAttribLocation(program, attribute.name)
      @gl.enableVertexAttribArray(loc)
      @attributes[attribute.name] = {
        location: loc
        type: attribute.type
        size: attribute.size
      }
    @


  _setTexture: (img, tex, empty) =>
    @gl.bindTexture(@gl.TEXTURE_2D, tex)
    @gl.pixelStorei(@gl.UNPACK_FLIP_Y_WEBGL, true)
    @gl.texParameteri(@gl.TEXTURE_2D, @gl.TEXTURE_MAG_FILTER, @gl.LINEAR)
    @gl.texParameteri(@gl.TEXTURE_2D, @gl.TEXTURE_MIN_FILTER, @gl.LINEAR)
    @gl.texParameteri(@gl.TEXTURE_2D, @gl.TEXTURE_WRAP_S, @gl.CLAMP_TO_EDGE)
    @gl.texParameteri(@gl.TEXTURE_2D, @gl.TEXTURE_WRAP_T, @gl.CLAMP_TO_EDGE)
    if empty
      @gl.texImage2D(@gl.TEXTURE_2D, 0, @gl.RGBA,
        img.width, img.height, 0, @gl.RGBA, @gl.UNSIGNED_BYTE, null)
    else
      @gl.texImage2D(@gl.TEXTURE_2D, 0, @gl.RGBA, @gl.RGBA, @gl.UNSIGNED_BYTE, img)
    @gl.bindTexture(@gl.TEXTURE_2D, null)

  texture: (source, tex, callback) ->
    return source if source instanceof WebGLTexture
    tex ?= @gl.createTexture()
    if typeof source is 'string'
      img = document.createElement('img')
      img.onload = =>
        @_setTexture(img, tex)
        if callback
          callback(tex)
        else if @_drawArg
          @gl.bindTexture(@gl.TEXTURE_2D, tex)
          @draw(@_drawArg...)
      img.src = source
    else
      # <img>, <video>, <canvas>, ImageData object, etc.
      @_setTexture(source, tex)
    tex


  variable: (param, cacheTexture) ->
    obj = {}
    for name in Object.keys param
      value = param[name]
      if not value?
        obj[name] = null
      else if uniform = @uniforms[name]
        if ~TYPESUFFIX[uniform.type].indexOf('Sampler')
          if cacheTexture
            value = @textures[name] = @texture(value, @textures[name])
          else
            value = @texture(value)
        obj[name] = value
      else
        buffer = @gl.createBuffer()
        if attribute = @attributes[name]
          @gl.bindBuffer(@gl.ARRAY_BUFFER, buffer)
          @gl.bufferData(@gl.ARRAY_BUFFER, new Float32Array(value), @gl.STATIC_DRAW)
        else
          @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, buffer)
          @gl.bufferData(@gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(value), @gl.STATIC_DRAW)
        buffer.length = value.length
        obj[name] = buffer
    obj


  _bindUniform: (uniform, value) ->
    suffix = TYPESUFFIX[uniform.type]
    if ~suffix.indexOf('Sampler')
      type = if suffix is 'Sampler2D' then @gl.TEXTURE_2D else @gl.TEXTURE_CUBE_MAP
      @gl.activeTexture(@gl['TEXTURE' + @_texnum])
      @gl.bindTexture(type, value)
      @gl.uniform1i(uniform.location, @_texnum)
      @_texnum++
    else if ~suffix.indexOf('Matrix')
      @gl["uniform" + suffix](uniform.location, false, new Float32Array(value))
    else
      @gl["uniform" + suffix](uniform.location, value)

  _bindAttribute: (attribute, value) ->
    size = TYPESIZE[attribute.type]
    @gl.bindBuffer(@gl.ARRAY_BUFFER, value)
    @gl.vertexAttribPointer(attribute.location, size, @gl.FLOAT, false, 0, 0)
    @_numArrays = value.length / size

  bind: (obj) ->
    @_drawArg = undefined

    for name in Object.keys obj
      value = obj[name]
      if uniform = @uniforms[name]
        @_bindUniform(uniform, value)
      else if attribute = @attributes[name]
        @_bindAttribute(attribute, value)
      else if value
        @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, value)
        @_numElements = value.length
        @_useElementArray = true
      else
        @gl.bindBuffer(@gl.ELEMENT_ARRAY_BUFFER, null)
        @_useElementArray = false
    @


  bindVars: (param) ->
    @bind @variable(param, true)


  frame: (width=@width, height=@height, option) ->
    # option = color:true, depth:true, stencil:true
    fb = @gl.createFramebuffer()
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, fb)
    tex = @gl.createTexture()
    @_setTexture({ width, height }, tex, true)

    rb = @gl.createRenderbuffer()
    @gl.bindRenderbuffer(@gl.RENDERBUFFER, rb)
    @gl.renderbufferStorage(@gl.RENDERBUFFER, @gl.DEPTH_COMPONENT16, width, height)

    @gl.framebufferTexture2D(@gl.FRAMEBUFFER, @gl.COLOR_ATTACHMENT0,
      @gl.TEXTURE_2D, tex, 0)
    @gl.framebufferRenderbuffer(@gl.FRAMEBUFFER, @gl.DEPTH_ATTACHMENT,
      @gl.RENDERBUFFER, rb)

    @gl.bindRenderbuffer(@gl.RENDERBUFFER, null)
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, null)

    fb.color = tex
    fb


  draw: (type, num) ->
    if @_useElementArray
      num ?= @_numElements
      @gl.drawElements(@gl[type or 'TRIANGLES'], num, @gl.UNSIGNED_SHORT, 0)
    else
      num ?= @_numArrays
      @gl.drawArrays(@gl[type or 'TRIANGLE_STRIP'], 0, num)
    @_drawArg = [type, num]
    @_texnum = 0
    @

  drawFrame: (fb, type, num) ->
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, fb)
    @draw(type, num)
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, null)
    @


  clear: ->
    @gl.clear(@gl.COLOR_BUFFER_BIT | @gl.DEPTH_BUFFER_BIT)
    @

  clearFrame: (fb) ->
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, fb)
    @clear()
    @gl.bindFramebuffer(@gl.FRAMEBUFFER, null)
    @


  read: ->
    canv = @gl.canvas
    width = canv.width
    height = canv.height
    array = new Uint8Array(width * height * 4)
    @gl.readPixels(0, 0, width, height, @gl.RGBA, @gl.UNSIGNED_BYTE, array)
    array


if window
  window.MicroGL = MicroGL
  r = 'equestAnimationFrame'
  window['r'+ r] or= window['webkitR'+ r] or window['mozR'+ r] or (f) -> setTimeout(f, 1000/60)