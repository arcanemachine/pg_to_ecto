defmodule PostgresToEcto.Result do
  @moduledoc "The result of a PostgresToEcto generation attempt."

  @type t :: %__MODULE__{
          files: [PostgresToEcto.FileChange.t()],
          diagnostics: [PostgresToEcto.Diagnostic.t()]
        }

  @enforce_keys [:files, :diagnostics]
  defstruct files: [], diagnostics: []
end

defmodule PostgresToEcto.FileChange do
  @moduledoc "A generated file path and the action planned for that path."

  @type t :: %__MODULE__{path: String.t(), action: :create | :update | :unchanged | :blocked}

  @enforce_keys [:path, :action]
  defstruct [:path, :action]
end

defmodule PostgresToEcto.Diagnostic do
  @moduledoc "A structured generation diagnostic."

  @type t :: %__MODULE__{
          severity: :error | :warning,
          code: atom(),
          message: String.t()
        }

  @enforce_keys [:severity, :code, :message]
  defstruct [:severity, :code, :message]
end
