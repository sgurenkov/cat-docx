import { createSignal, createEffect, For, Show } from 'solid-js'
import { listContent, readRecord } from './wasm'
import './style.css'
import { formatBytes } from './utils'

interface CentralDirectoryRecord {
  file_name: string
  info: {
    signature: number
    version_m: number
    version_n: number
    flag: number
    method: number
    modified_t: number
    modifield_d: number
    crc32: number
    size_c: number // compressed size
    size_u: number // uncompressed size
    file_name_len: number // length of the file name (bytes)
    extra_field_len: number // length of the extra field (bytes)
    comment_len: number // length of the comment section (bytes)
    disk_number: number
    int_attr: number
    ext_attrs: number
    offset: number // offset of the file within archive (bytes)
  }
}

let codeRef: { xml: string }
let imgRef: HTMLImageElement

function isImage(record: CentralDirectoryRecord): boolean {
  const ext = record.file_name.split('.').pop()
  if (ext) {
    return ['jpg', 'jpeg', 'png', 'gif', 'svg'].includes(ext.toLowerCase())
  }
  return false
}

export function DataExplorer(props: { file: File }) {
  const [directory, setDirectory] = createSignal<CentralDirectoryRecord[]>()
  const [record, setRecord] = createSignal<CentralDirectoryRecord>()

  createEffect(() => {
    listContent(props.file).then((result) => {
      const content: CentralDirectoryRecord[] = JSON.parse(result)
      // content.sort((a, b) => (a.file_name > b.file_name ? 1 : -1))
      setDirectory(content)
    })
  })

  const selectRecord = async (index: number) => {
    if (!directory()) return
    const record = directory()![index]
    setRecord(record)
    if (isImage(record)) {
      const content = await readRecord(props.file, index, true)
      imgRef.src = URL.createObjectURL(content as Blob)
    } else {
      const content = (await readRecord(props.file, index)) as string
      codeRef.xml = content
    }
  }

  return (
    <div class="flex h-full">
      <div class="p-10 pt-15">
        <Show when={directory()}>
          <For each={directory()!}>
            {(item: CentralDirectoryRecord, index) => (
              <div class="m-1">
                <a
                  class={`hover:text-pink-500 ${item.file_name === record()?.file_name && "font-bold"}`}
                  href="#"
                  onClick={() => selectRecord(index())}
                >
                  {item.file_name}
                </a>
                <br /><span>(c: {formatBytes(item.info.size_c)}, u: {formatBytes(item.info.size_u)})</span>
              </div>
            )}
          </For>
        </Show>
      </div>
      <div class="w-full h-full p-3 overflow-y-auto">
        <Show when={record() && !isImage(record()!)}>
          <div class="w-full">
          {/* @ts-expect-error */}
          <xml-viewer-component ref={codeRef} />
          </div>
        </Show>
        <Show when={record() && isImage(record()!)}>
          <div class="chessboard h-full w-full">
            <img class="max-w-full" ref={imgRef} />
          </div>
        </Show>
      </div>
    </div>
  )
}
