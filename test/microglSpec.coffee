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

    it 'should set #width and #height', ->
      gl.init(null, 128, 256)
      expect(gl.width).toBe 128
      expect(gl.height).toBe 256

    # canvas.style.width|height を
    # devicePixelRatio に応じてでかくする必要がある

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

    it 'should not create texture if 1st argument is a WebGLTexture', ->
      tex = gl.texture 'test/test.jpg'
      spyOn(gl.gl, 'createTexture').andCallThrough()
      gl.texture tex
      expect(gl.gl.createTexture).not.toHaveBeenCalled()

    it 'should not create texture if 2nd argument is a WebGLTexture', ->
      tex = gl.texture 'test/test.jpg'
      spyOn(gl.gl, 'createTexture').andCallThrough()
      gl.texture 'test/test.jpg', tex
      expect(gl.gl.createTexture).not.toHaveBeenCalled()

  describe '#variable()', ->
    gl.program vshader, fshader

    it 'should return a variables object', ->
      vari = gl.variable {
        a_position: [0,0,1,1, 0,1,1,1, 1,1,1,1]
        INDEX: [0, 1, 2]
        NOT_EXIST_ON_SHADER: 42
      }
      expect(vari).toBeDefined()

    it 'should not cache texture', ->
      gl.variable { u_sampler: 'test/test.jpg' }
      spyOn(gl.gl, 'createTexture').andCallThrough()
      gl.variable { u_sampler: 'test/test.jpg' }
      expect(gl.gl.createTexture).toHaveBeenCalled()

  describe '#bindVars()', ->
    gl.program vshader, fshader

    it 'should cache texture', ->
      gl.bindVars { u_sampler: 'test/test.jpg' }
      spyOn(gl.gl, 'createTexture').andCallThrough()
      gl.bindVars { u_sampler: 'test/test.jpg' }
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
      expect(gl.gl.getError()).toBe gl.gl.NO_ERROR
      expect(gl.gl.drawArrays).toHaveBeenCalledWith(gl.gl.TRIANGLE_STRIP, 0, 3)

    it 'should allow to change drawing mode', ->
      gl.bindVars {
        a_position: [0,0,1,1, 0,1,1,1, 1,1,1,1]
        a_texCoord: [0,0, 0,1, 1,1]
        u_sampler: 'test/test.jpg'
      }
      spyOn(gl.gl, 'drawArrays').andCallThrough()
      gl.draw 'TRIANGLES'
      expect(gl.gl.getError()).toBe gl.gl.NO_ERROR
      expect(gl.gl.drawArrays).toHaveBeenCalledWith(gl.gl.TRIANGLES, 0, 3)

    it 'should call #gl.drawElements() if INDEX is given', ->
      gl.bindVars {
        INDEX: [0, 1, 2]
      }
      gl.bindVars {
        a_position: [0,0,1,1, 0,1,1,1, 1,1,1,1]
        a_texCoord: [0,0, 0,1, 1,1]
        u_sampler: 'test/test.jpg'
      }
      spyOn(gl.gl, 'drawElements').andCallThrough()
      gl.draw()
      # drawElements() が正しい引数で呼ばれたとしても
      # もし element array buffer が正しく bind されていないと
      # `no ELEMENT_ARRAY_BUFFER bound` error が発生するかもしれない
      expect(gl.gl.getError()).toBe gl.gl.NO_ERROR
      expect(gl.gl.drawElements.mostRecentCall.args[0..1]).toEqual [gl.gl.TRIANGLES, 3]

    it 'should call #gl.drawArrays() after INDEX is deleted', ->
      gl.bindVars {
        INDEX: [0, 1, 2]
        a_position: [0,0,1,1, 0,1,1,1, 1,1,1,1]
        a_texCoord: [0,0, 0,1, 1,1]
        u_sampler: 'test/test.jpg'
      }
      gl.bindVars {
        INDEX: null
      }
      spyOn(gl.gl, 'drawArrays').andCallThrough()
      gl.draw()
      expect(gl.gl.getError()).toBe gl.gl.NO_ERROR
      expect(gl.gl.drawArrays).toHaveBeenCalledWith(gl.gl.TRIANGLE_STRIP, 0, 3)

  describe '#read()', ->
    imagedata = null
    gl.init(document.body, 8, 8)
    gl.program vshader, fshader
    gl.texture 'test/red.gif', null, (tex) ->
      gl.bindVars {
        a_position: [-1,-1,1,1, -1,1,1,1, 1,-1,1,1, 1,1,1,1]
        a_texCoord: [0,0, 0,1, 1,0, 1,1]
        u_sampler: tex
      }
      gl.draw()
      imagedata = gl.read()

    it 'should return an array-like, its length is "width x height x 4"', ->
      expect(imagedata.length).toBe 8 * 8 * 4

    it 'should return image-data properly', ->
      waitsFor 1000, -> !!imagedata
      runs ->
        for i in [0...imagedata.length] by 4
          expect(imagedata[i  ]).toBe 255
          expect(imagedata[i+1]).toBe 0
          expect(imagedata[i+2]).toBe 0
          expect(imagedata[i+3]).toBe 255


  fshader_multi = '''
    precision mediump float;
    uniform sampler2D red;
    uniform sampler2D u_sampler;
    varying vec2 v_texCoord;
    void main(){
      vec4 color = texture2D(red, vec2(0.0, 0.0));
      if(color.r != 1.0){ // expect to be false
        gl_FragColor = vec4(0.0, 1.0, 0.0, 1.0);
      } else {
        gl_FragColor = texture2D(u_sampler, vec2(0.5, 0.5));
      }
    }
  '''

  describe '[testing multiple texture]', ->
    loaded = 0
    images = {}
    prepareImage = (src, name) ->
      img = document.createElement 'img'
      img.onload = ->
        images[name] = img
        loaded++
      img.src = src

    prepareImage 'test/red.gif', 'red'
    prepareImage 'test/test.jpg', 'u_sampler'

    it 'texture2D() (in shaders) should return property values', ->
      waitsFor 1000, -> loaded is 2
      runs ->
        gl.init(null, 1, 1).program vshader, fshader_multi
        gl.bindVars(
          a_position:[-1,-1,1,1, -1,1,1,1, 1,-1,1,1, 1,1,1,1]
          a_texCoord: [0,0, 0,1, 1,0, 1,1]
          red: images.red
        ).bindVars(
          u_sampler: images.u_sampler
        ).draw()
        imagedata = gl.read()

        expect(imagedata[0]).not.toBe 0
        expect(imagedata[1]).not.toBe 255
        expect(imagedata[2]).not.toBe 0
        expect(imagedata[3]).toBe 255

    it 'texture2D() (in shaders) should return property values', ->
      waitsFor 1000, -> loaded is 2
      runs ->
        gl.init(null, 1, 1).program vshader, fshader_multi
        gl.bindVars(
          a_position:[-1,-1,1,1, -1,1,1,1, 1,-1,1,1, 1,1,1,1]
          a_texCoord: [0,0, 0,1, 1,0, 1,1]
          red: images.red
          u_sampler: images.u_sampler
        ).draw()
        imagedata = gl.read()

        expect(imagedata[0]).not.toBe 0
        expect(imagedata[1]).not.toBe 255
        expect(imagedata[2]).not.toBe 0
        expect(imagedata[3]).toBe 255