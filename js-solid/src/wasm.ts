const res = {
  ptr: 0,
  len: 0
}

function on_result(ptr: number, len: number): void {
  res.ptr = ptr
  res.len = len
  console.log(`Result ptr: ${ptr}, len: ${len}`)
}

const wasmBuffer = await fetch('docls.wasm').then((response) =>
  response.arrayBuffer()
)

async function fileToByteArray(file: File): Promise<Uint8Array> {
  const buffer = await file
    .arrayBuffer()
  return new Uint8Array(buffer)
}

async function initModuleWithData(file: File): Promise<{
  module: WebAssembly.WebAssemblyInstantiatedSource
  memory: WebAssembly.Memory,
  bytes: number
}> {
  const data = await fileToByteArray(file)
  const memory = new WebAssembly.Memory({ initial: 20, maximum: 1000 })
  const module = await WebAssembly.instantiate(wasmBuffer, {
    env: {
      on_result,
      memory
    }
  })
  new Uint8Array(memory.buffer).set(data)
  return { memory, module, bytes: data.length }
}

export async function readHtml(file: File): Promise<string> {
  const { module, memory, bytes } = await initModuleWithData(file)
  const toHtml: any = module.instance.exports.toHtml

  const result_code = runMeasure(toHtml, 'toHtml', bytes)
  if (result_code == 0) {
    return readResult(memory)
  } else {
    throw Error(`Error in a wasm module, code - ${result_code}`)
  }
}

export async function listContent(file: File) {
  const { module, memory, bytes } = await initModuleWithData(file)
  const fn: any = module.instance.exports.listContent

  const result_code = runMeasure(fn, 'listContent', bytes)
  if (result_code == 0) {
    return readResult(memory)
  } else {
    throw Error(`Error in a wasm module, code - ${result_code}`)
  }
}

export async function readRecord(file: File, index: number, raw = false) {
  const { module, memory, bytes } = await initModuleWithData(file)
  const fn: any = module.instance.exports.readRecord

  const result_code = runMeasure(fn, 'readRecord', bytes, index)
  if (result_code == 0) {
    return raw ? readResultRaw(memory) : readResult(memory)
  } else {
    throw Error(`Error in a wasm module, code - ${result_code}`)
  }
}

function readResult(memory: WebAssembly.Memory): string {
  const { ptr, len } = res
  const decoder = new TextDecoder()
  return decoder.decode(memory.buffer.slice(ptr, ptr + len))
}

function readResultRaw(memory: WebAssembly.Memory): Blob {
  const { ptr, len } = res

  return new Blob([memory.buffer.slice(ptr, ptr + len)])
}

function runMeasure(
  fn: (a: number, b: number, c?: number) => number,
  operation: string,
  bytes: number,
  index?: number
): number {
  const t1 = performance.now()
  console.info(`offset: ${0}, len: ${bytes}`)
  const res_code = fn(0, bytes, index)
  const t2 = performance.now()

  const debug_log = `[wasm: ${operation}() ${(t2 - t1).toFixed(0)}ms] - ${
    res_code === 0 ? 'ok' : 'err ' + res_code
  }`
  console.debug(debug_log)

  return res_code
}
