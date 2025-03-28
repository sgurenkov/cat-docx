import { Show, createEffect, createSignal } from 'solid-js'
import { formatBytes } from './utils'
// import { readHeader } from './wasm'

interface Props {
  file: File
  unsetFile: () => void
}

export function HeaderInfo(props: Props) {

  return (
    <div class="flex gap-5">
      <div class="flex flex-col gap-1">
        <div>
          File Name: <strong>{props.file.name}</strong>
        </div>
      </div>
      <div class="flex flex-col gap-1">
        <div>
          Compressed Size: <strong>{formatBytes(props.file.size)}</strong>
        </div>
      </div>
    </div>
  )
}
