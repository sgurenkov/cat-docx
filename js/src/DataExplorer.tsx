import React, { useRef, useEffect, useState } from "react";
import XMLViewer from "react-xml-viewer";
import { listContent, readRecord } from "./wasm";
import "./style.css";
import { formatBytes } from "./utils";

interface CentralDirectoryRecord {
  file_name: string;
  info: {
    signature: number;
    version_m: number;
    version_n: number;
    flag: number;
    method: number;
    modified_t: number;
    modifield_d: number;
    crc32: number;
    size_c: number; // compressed size
    size_u: number; // uncompressed size
    file_name_len: number; // length of the file name (bytes)
    extra_field_len: number; // length of the extra field (bytes)
    comment_len: number; // length of the comment section (bytes)
    disk_number: number;
    int_attr: number;
    ext_attrs: number;
    offset: number; // offset of the file within archive (bytes)
  };
}

function isImage(record: CentralDirectoryRecord): boolean {
  const ext = record.file_name.split(".").pop();
  if (ext) {
    return ["jpg", "jpeg", "png", "gif", "svg"].includes(ext.toLowerCase());
  }
  return false;
}

export function DataExplorer(props: { file: File }) {
  const [directory, setDirectory] = useState<CentralDirectoryRecord[]>();
  const [record, setRecord] = useState<CentralDirectoryRecord>();
  const [xml, setXml] = useState<string>();
  const imgRef = useRef<HTMLImageElement>(null);

  useEffect(() => {
    listContent(props.file).then((result) => {
      const content: CentralDirectoryRecord[] = JSON.parse(result);
      // content.sort((a, b) => (a.file_name > b.file_name ? 1 : -1))
      setDirectory(content);
    });
  }, []);

  const selectRecord = async (index: number) => {
    if (!directory) return;
    const record = directory![index];
    setRecord(record);
    if (isImage(record) && imgRef.current) {
      const content = await readRecord(props.file, index, true);
      imgRef.current.src = URL.createObjectURL(content as Blob);
    } else {
      const content = (await readRecord(props.file, index)) as string;
      setXml(content);
    }
  };

  return (
    <div className="flex h-full">
      <div className="p-10 pt-15 overflow-auto">
        {directory &&
          directory.map((item: CentralDirectoryRecord, index: number) => (
            <div className="m-1" key={index}>
              <a
                className={`hover:text-pink-500 ${item.file_name === record?.file_name && "font-bold"}`}
                href="#"
                onClick={() => selectRecord(index)}
              >
                {item.file_name}
              </a>
              <br />
              <span>
                (c: {formatBytes(item.info.size_c)}, u:{" "}
                {formatBytes(item.info.size_u)})
              </span>
            </div>
          ))}
      </div>
      <div className="w-full h-full p-3 overflow-y-auto">
        {record && xml && !isImage(record!) && (
          <div className="w-full p-5">
            <XMLViewer xml={xml} collapsible />
          </div>
        )}
        {record && isImage(record!) && (
          <div className="chessboard h-full w-full">
            <img className="max-w-full" ref={imgRef} />
          </div>
        )}
      </div>
    </div>
  );
}
