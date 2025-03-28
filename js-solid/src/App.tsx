import { Component, createSignal, Show } from 'solid-js'
import './wasm'
import { DataExplorer } from './DataExplorer'
import { HeaderInfo } from './HeaderInfo'

export type ResultType = 'json' | 'html' | 'header'

const App: Component = () => {
  const [file, setFile] = createSignal<File | null>()

  return (
    <div class="h-full drop-zone flex flex-col color-sky-900">
      <header class="flex items-center gap-8 bg-sky-100">
        <div class="p-6 m-0">
          <h1 class="m-0 p-0 text-4xl">Docx Analyzer</h1>
        </div>
        <Show when={file()}>
          <div class="m-l-5">
            <HeaderInfo file={file()!} unsetFile={setFile} />
          </div>
          <div class="m-l-10">
            <a class="btn" onClick={() => setFile()}>
              x
            </a>
          </div>
        </Show>
      </header>
      <div class="flex-grow-1 h-full overflow-hidden">
        <Show when={!file()}>
          <FilePicker onFileSet={setFile} />
        </Show>
        <Show when={file()}>
          <DataExplorer file={file()!} />
        </Show>
      </div>
    </div>
  )
}

function FilePicker(props: { onFileSet: (file: File | null) => void }) {
  const onChange = (event: any) => {
    const files = (event.target as HTMLInputElement).files
    if (files && files.length) {
      props.onFileSet(files.item(0))
    }
  }
  const onDrop = (event: any) => {
    const files = (event as DragEvent).dataTransfer?.files
    if (files && files.length) {
      props.onFileSet(files.item(0))
    }
  }
  return (
    <div class="relative h-full flex justify-center items-center group">
      <input
        type="file"
        class="absolute h-full w-full opacity-0 cursor-pointer"
        accept=".docx"
        onChange={onChange}
        onDrop={onDrop}
      />
      <div class="text-4xl leading-loose text-center color-gray-800 font-bold p-8 rounded-lg group-hover:border-dashed">
        Drop file here or <br /> select from computer
      </div>
    </div>
  )
}

export default App
