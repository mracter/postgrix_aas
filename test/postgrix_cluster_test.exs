defmodule PostgrixCluster.Test do
  use ExUnit.Case
  use ExUnit.CaseTemplate
  alias PostgrixCluster.{API}

  using do
    quote do
      import Ecto
      import Ecto.Query
    end
  end

  setup do
    db_name = "testdb"
    schema = "public"
    vault_user = "vault"
    db_owner = "owner"
    hostname = "localhost"

    port =
      cond do
        Mix.env() == :test ->
          5433

        Mix.env() == :dev ->
          5432

        true ->
          5433
      end

    username = "postgres"
    password = "mysecretpassword2"
    database = "postgres_cluster"

    on_exit(fn ->
      {:ok, pid} =
        Postgrex.start_link(
          hostname: hostname,
          port: port,
          username: username,
          password: password,
          database: database
        )

      dropSchema(pid, schema)
      dropDatabase(pid, db_name)
      dropRole(pid, vault_user)
      dropRole(pid, db_owner)
    end)

    {:ok, pid} =
      start_supervised(
        {Postgrex,
         [
           hostname: hostname,
           port: port,
           username: username,
           password: password,
           database: database,
           pool_size: 20,
           pool_timeout: 15_000,
           timeout: 15_000
         ]}
      )

    {:ok, pid: pid}
  end

  defp roleExists?(pid, role) do
    case Postgrex.query!(pid, "SELECT 1 FROM pg_roles WHERE rolname='#{role}';", []) do
      {:ok, result} -> result.rows == [[1]]
      _ -> false
    end
  end

  defp dropRole(pid, role) do
    Postgrex.query(pid, "DROP ROLE IF EXISTS #{role};", [])
  end

  defp createDatabase(pid, db_name) do
    Postgrex.query(pid, "CREATE DATABASE #{db_name} WITH OWNER DEFAULT;", [])
  end

  defp dropDatabase(pid, db_name) do
    Postgrex.query(pid, "DROP DATABASE IF EXISTS #{db_name};", [])
  end

  defp createSchema(pid, schema) do
    Postgrex.query(pid, "CREATE SCHEMA IF NOT EXISTS #{schema};", [])
  end

  defp dropSchema(pid, schema) do
    Postgrex.query(pid, "DROP SCHEMA IF EXISTS #{schema};", [])
  end

  defp addVaultRole(pid, db_name, vault_user, vault_password) do
    Postgrex.query(pid, "CREATE ROLE #{vault_user} WITH CREATEROLE
    INHERIT LOGIN ENCRYPTED PASSWORD \'#{vault_password}\';", [])
    Postgrex.query(pid, "GRANT ALL PRIVILEGES ON DATABASE #{db_name} TO
    #{vault_user} WITH GRANT OPTION;", [])
  end

  test "create a database", context do
    db_name = "testdb"
    pid = context[:pid]

    API.createDatabase(pid, db_name)
    Process.sleep(1000)
    assert API.databaseExists?(pid, db_name) == true
  end

  test "add Vault master role", context do
    db_name = "testdb"
    schema = "public"
    vault_user = "vault"
    vault_password = "vaultpass"
    pid = context[:pid]

    createDatabase(pid, db_name)
    createSchema(pid, schema)
    API.addVaultRole(pid, db_name, vault_user, vault_password)
    Process.sleep(1000)
    assert API.roleExists?(pid, vault_user) == true
  end

  test "add an owner role, grant the owner role to the Vault user", context do
    db_name = "testdb"
    schema = "public"
    vault_user = "vault"
    vault_password = "vaultpass"
    db_owner = "owner"
    owner_pass = "ownerpass"
    pid = context[:pid]

    {:ok, result} = createDatabase(pid, db_name)
    IO.inspect(result)
    Process.sleep(100)
    {:ok, result} = createSchema(pid, schema)
    IO.inspect(result)
    Process.sleep(100)
    {:ok, result} = addVaultRole(pid, db_name, vault_user, vault_password)
    IO.inspect(result)
    Process.sleep(100)

    {:ok, result} = API.addOwnerRole(pid, db_name, db_owner, owner_pass)
    IO.inspect(result)
    # Sleep to avoid race condition where check is made before transaction completes
    Process.sleep(1000)
    assert API.roleExists?(pid, db_owner) == true

    {:ok, result} = API.grantOwnerRole(pid, db_owner, vault_user)
    IO.inspect(result)
    Process.sleep(1000)
    assert API.hasRole?(pid, vault_user, db_owner) == true
  end

  test "test that parameter validation only allows words", context do
    value1 = "testword"
    assert API.isValid?(value1) == true

    value2 = "'--test;"
    assert API.isValid?(value2) == false
  end
end
