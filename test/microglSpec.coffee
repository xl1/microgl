describe 'MicroGL', ->
  $$ = (query) ->
    Array::slice.call document.querySelectorAll(query)

  gl = new MicroGL()
  vshader = '''
    attribute vec4 a_position;
    attribute vec2 a_texCoord;
    varying vec2 v_texCoord;
    void main(){ v_texCoord = a_texCoord; gl_Position = a_position; }
  '''
  fshader = '''
    precision mediump float;
    uniform sampler2D u_sampler;
    varying vec2 v_texCoord;
    void main(){ gl_FragColor = texture2D(u_sampler, v_texCoord); }
  '''

  describe '#enabled', ->
    it 'should be true if WebGL is enabled', ->
      expect(gl.enabled).toBe true

  describe '#gl', ->
    it 'should be a WebGLRenderingContext', ->
      expect(gl.gl instanceof window.WebGLRenderingContext).toBe true

  describe '#init()', ->
    it 'should append canvas if 1st argument is exist', ->
      gl.init(document.body)
      expect($$ 'body > canvas').toContain gl.gl.canvas
      document.body.removeChild(gl.gl.canvas)

    it 'should append canvas ONLY if above', ->
      gl.init(null)
      expect($$ '*').not.toContain gl.gl.canvas

    it 'should set size of canvas', ->
      gl.init(null, 256, 128)
      { width, height } = gl.gl.canvas
      expect(width).toBe 256
      expect(height).toBe 128

  describe '#makeProgram()', ->
    it 'should return a program', ->
      program = gl.makeProgram(vshader, fshader)
      expect(program).toBeDefined()

    it 'should return nothing if shader has errors', ->
      program = gl.makeProgram(vshader + 'HOGE', fshader)
      expect(program).toBeUndefined()

  describe '#program()', ->
    it 'should allow 2 arguments: (vshader, fshader)', ->
      gl.program(vshader, fshader)
    it 'should allow 1 argument: (program)', ->
      gl.program gl.makeProgram(vshader, fshader)

    # #attributes and #uniforms do not need to be public.
    xit 'should register attributes and uniforms', ->
      attrs = Object.keys gl.attributes
      expect(attrs).toContain 'a_position'
      expect(attrs).toContain 'a_texCoord'
      unifs = Object.keys gl.uniforms
      expect(unifs).toContain 'u_sampler'

  describe '#texture()', ->
    # prepareTexture() にリネームを検討中
    it 'should return a texture', ->
      tex = gl.texture 'test/test.jpg'
      expect(tex).toBeDefined()

    it 'should callback after loading texture image', ->
      tex = null
      gl.texture 'test/test.jpg', null, (t) -> tex = t
      waitsFor 1000, -> !!tex

  describe '#variable()', ->
    gl.program vshader, fshader

    it 'should return a variables object', ->
      vari = gl.variable {
        a_position: [0,0,1,1, 0,1,1,1, 1,1,1,1]
        INDEX: [0, 1, 2]
        NOT_EXIST_ON_SHADER: 42
      }
      expect(vari).toBeDefined()

    it 'should cache texture', ->
      gl.variable { u_sampler: 'test/test.jpg' }
      spyOn(gl.gl, 'createTexture').andCallThrough()
      gl.variable { u_sampler: 'test/test.jpg' }
      expect(gl.gl.createTexture).not.toHaveBeenCalled()

  describe '#frame()', ->
    it 'should return a framebuffer', ->
      frame = gl.frame()
      expect(frame).toBeDefined()

    it 'frame returned should have color texture', ->
      frame = gl.frame()
      expect(frame.color).toBeDefined()
    # depth buffer と stencil buffer も

  describe '#draw()', ->
    gl.init null
    gl.program vshader, fshader

    it 'should call #gl.drawArrays()', ->
      gl.bindVars {
        a_position: [0,0,1,1, 0,1,1,1, 1,1,1,1]
        a_texCoord: [0,0, 0,1, 1,1]
        u_sampler: 'test/test.jpg'
      }
      spyOn(gl.gl, 'drawArrays').andCallThrough()
      gl.draw()
      expect(gl.gl.drawArrays).toHaveBeenCalledWith(gl.gl.TRIANGLE_STRIP, 0, 3)

    it 'should allow to change drawing mode', ->
      gl.bindVars {
        a_position: [0,0,1,1, 0,1,1,1, 1,1,1,1]
        a_texCoord: [0,0, 0,1, 1,1]
        u_sampler: 'test/test.jpg'
      }
      spyOn(gl.gl, 'drawArrays').andCallThrough()
      gl.draw 'TRIANGLES'
      expect(gl.gl.drawArrays).toHaveBeenCalledWith(gl.gl.TRIANGLES, 0, 3)

    it 'should call #gl.drawElements() if INDEX is given', ->
      gl.bindVars {
        a_position: [0,0,1,1, 0,1,1,1, 1,1,1,1]
        a_texCoord: [0,0, 0,1, 1,1]
        u_sampler: 'test/test.jpg'
        INDEX: [0, 1, 2]
      }
      spyOn(gl.gl, 'drawElements').andCallThrough()
      gl.draw()
      expect(gl.gl.drawElements.mostRecentCall.args[0..1]).toEqual [gl.gl.TRIANGLES, 3]

  describe '#read()', ->
    gl.init(document.body, 64, 32)
    gl.program vshader, fshader
    gl.bindVars {
      a_position: [0,0,1,1, 0,1,1,1, 1,1,1,1]
      a_texCoord: [0,0, 0,1, 1,1]
      u_sampler: 'test/test.jpg'
    }
    gl.draw()
    imagedata = gl.read()

    it 'should return an array-like, its length is "width x height x 4"', ->
      expect(imagedata.length).toBe 64 * 32 * 4

    #it 'should return image-data properly (check alpha == 255)', ->
    #  for d in imagedata by 4
    #    expect(d).toBe 255