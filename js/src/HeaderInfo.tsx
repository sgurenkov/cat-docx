import { FC } from "react";
import { formatBytes } from "./utils";

interface Props {
  file: File;
  unsetFile: () => void;
}

export const HeaderInfo: FC<Props> = (props) => {
  return (
    <div className="flex gap-5">
      <div className="flex flex-col gap-1">
        <div>
          File Name: <strong>{props.file.name}</strong>
        </div>
      </div>
      <div className="flex flex-col gap-1">
        <div>
          Compressed Size: <strong>{formatBytes(props.file.size)}</strong>
        </div>
      </div>
    </div>
  );
};
