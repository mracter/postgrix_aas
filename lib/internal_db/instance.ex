defmodule InternalDB.Instance do
  use Ecto.Schema
  import Ecto.Changeset

  alias InternalDB.Instance

  @primary_key {:id, :id, autogenerate: true}
  schema "instances" do
    field :ip, :string
    field :port, :integer
    field :db_name, :string
    field :instance_id, :string
    has_many :bindings, InternalDB.Binding, foreign_key: :instance_id

    timestamps()
  end


  @fields ~w(ip port db_name instance_id)

  def changeset(data, params \\ %{}) do
    data
    |> cast(params, @fields)
    |> validate_required([:ip, :port, :instance_id])
    |> validate_number(:port, greater_than_or_equal_to: Integer.new(0))
    |> validate_number(:port, lesser_than_or_equal_to: Integer.new(65535))
    |> unique_constraint(:ip, name: "instances_clusters_fk")
    |> foreign_key_constraint(:ip, name: "instances_clusters_fk")
  end
end
