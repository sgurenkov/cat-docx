import './style.css'

const res = {
  ptr: 0,
  len: 0
}

function on_result(ptr: number, len: number): void {
  res.ptr = ptr
  res.len = len
  console.log(`Result ptr: ${ptr}, len: ${len}`)
}

const wasmBuffer = await fetch('adf.wasm').then((response) =>
  response.arrayBuffer()
)

const input: HTMLInputElement = document.getElementById(
  'button'
) as HTMLInputElement
const out_document: HTMLElement = document.getElementById('out_document')!
out_document.attachShadow({ mode: 'open' })
const out: HTMLElement = document.getElementById('out')!

let fileBuffer: Uint8Array

input.addEventListener('change', (e: any) => {
  const file = e.target?.files[0]
  file.arrayBuffer().then((buffer: ArrayBuffer) => {
    fileBuffer = new Uint8Array(buffer)
    renderHtml()
    console.log(res)
  })
})

document.getElementById('html_button')!.addEventListener('click', renderHtml)
document.getElementById('json_button')!.addEventListener('click', renderJson)
document
  .getElementById('header_button')!
  .addEventListener('click', renderHeader)

async function initModuleWithData(data: Uint8Array): Promise<{
  module: WebAssembly.WebAssemblyInstantiatedSource
  memory: WebAssembly.Memory
}> {
  const memory = new WebAssembly.Memory({ initial: 20, maximum: 1000 })
  const module = await WebAssembly.instantiate(wasmBuffer, {
    env: {
      on_result,
      memory
    }
  })
  new Uint8Array(memory.buffer).set(data)
  return { memory, module }
}

async function renderHtml() {
  if (!fileBuffer || fileBuffer.length === 0) {
    console.log('file is empty')
    return
  }
  const { module, memory } = await initModuleWithData(fileBuffer)
  const toHtml: any = module.instance.exports.toHtml

  try {
    const result_code = runMeasure(toHtml, 'toHtml')
    if (result_code == 0) {
      out.style.display = 'none'
      out_document.style.display = 'block'
      out_document.shadowRoot!.innerHTML = readResult(memory)
    }
    console.log('Memory used: ', memory)
  } catch (e) {
    console.error(e)
    console.log(memory)
  }
}

async function renderJson() {
  if (!fileBuffer || fileBuffer.length === 0) {
    console.log('file is empty')
    return
  }
  const { module, memory } = await initModuleWithData(fileBuffer)
  const toJson: any = module.instance.exports.toJson

  try {
    const result_code = runMeasure(toJson, 'json')
    if (result_code == 0) {
      out_document.style.display = 'none'
      out.style.display = 'block'
      const result = readResult(memory)
      const json = JSON.parse(result)
      const {content, ...rest} = json
      const mapNode = (node) => {
        const res = {}
        res.type = node.type
        if (node.nodes) {
          res.nodes = node.nodes.reduce((acc, n) => {
            acc.push(mapNode(n))
            return acc
          }, [])
        }
        return res
      }
      const parsedContent = json.content.map(mapNode)
      out.innerHTML = `
        <h2>content field is excluded</h2>
        <pre>${JSON.stringify(rest, null, 2)}</pre>
      `
    }
    console.log('Memory used: ', memory)
  } catch (e) {
    console.error(e)
    console.log(memory)
  }
}

async function renderHeader() {
  if (!fileBuffer || fileBuffer.length === 0) {
    console.log('file is empty')
    return
  }
  const { module, memory } = await initModuleWithData(fileBuffer)
  const getHeader: any = module.instance.exports.getHeader

  try {
    const result_code = runMeasure(getHeader, 'getHeader')
    if (result_code == 0) {
      out_document.style.display = 'none'
      out.style.display = 'block'
      out.innerHTML = '<pre>' + readResult(memory) + '</pre>'
    }
    console.log('Memory used: ', memory)
  } catch (e) {
    console.error(e)
    console.log(memory)
  }
}

function readResult(memory: WebAssembly.Memory): string {
  const { ptr, len } = res
  const decoder = new TextDecoder()
  return decoder.decode(memory.buffer.slice(ptr, ptr + len))
}

function runMeasure(
  fn: (a: number, b: number) => number,
  operation: string
): number {
  const t1 = performance.now()
  console.info(`offset: ${0}, len: ${fileBuffer.length}`)
  const res_code = fn(0, fileBuffer.length)
  const t2 = performance.now()

  const debug_log = `[wasm: ${operation}() ${(t2 - t1).toFixed(0)}ms] - ${
    res_code === 0 ? 'ok' : 'err ' + res_code
  }`
  console.debug(debug_log)
  document.getElementById('debug_out')!.innerText = `Debug: ${debug_log}`

  return res_code
}
