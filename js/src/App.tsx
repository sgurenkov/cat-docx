import { FC, useState } from "react";
import "./wasm";
import { DataExplorer } from "./DataExplorer";
import { HeaderInfo } from "./HeaderInfo";

export type ResultType = "json" | "html" | "header";

const App: FC = () => {
  const [file, setFile] = useState<File | null>();

  return (
    <div className="h-full drop-zone flex flex-col color-sky-900">
      <header className="flex items-center gap-8 bg-sky-100">
        <div className="p-6 m-0">
          <h1 className="m-0 p-0 text-4xl">Docx Analyzer</h1>
        </div>
        {file && (
          <>
            <div className="m-l-5">
              <HeaderInfo file={file!} unsetFile={() => setFile(null)} />
            </div>
            <div className="m-l-10">
              <a className="btn" onClick={() => setFile(null)}>
                x
              </a>
            </div>
          </>
        )}
      </header>
      <div className="flex-grow-1 h-full overflow-hidden">
        {!file && <FilePicker onFileSet={setFile} />}
        {file && <DataExplorer file={file!} />}
      </div>
    </div>
  );
};

function FilePicker(props: { onFileSet: (file: File | null) => void }) {
  const onChange = (event: any) => {
    const files = (event.target as HTMLInputElement).files;
    if (files && files.length) {
      props.onFileSet(files.item(0));
    }
  };
  const onDrop = (event: any) => {
    const files = (event as DragEvent).dataTransfer?.files;
    if (files && files.length) {
      props.onFileSet(files.item(0));
    }
  };
  return (
    <div className="relative h-full flex justify-center items-center group">
      <input
        type="file"
        className="absolute h-full w-full opacity-0 cursor-pointer"
        accept=".docx"
        onChange={onChange}
        onDrop={onDrop}
      />
      <div className="text-4xl leading-loose text-center color-gray-800 font-bold p-8 rounded-lg group-hover:border-dashed">
        Drop file here or <br /> select from computer
      </div>
    </div>
  );
}

export default App;
