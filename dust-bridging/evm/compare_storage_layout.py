import argparse
import pandas as pd

NEW_DISPLAY_COLS = [
    "Name",
    "Type",
    "Slot",
    "Offset",
    "Bytes",
]

COLLISION_DISPLAY_COLS = [
    "Local Name",
    "Local Type",
    "Slot",
    "Offset",
    "Local Bytes",
    "Remote Name",
    "Remote Type",
    "Remote Bytes",
]


def parse_args():
    parser = argparse.ArgumentParser(
        prog="Storage Layout Comparison",
        description='Compares smart contract storage layouts')
    parser.add_argument("-local", help="Local storage layout file")
    parser.add_argument("-remote", help="Remote storage layout file")
    args = parser.parse_args()
    return (args.local, args.remote)


def read_forge_inspect_output(file_name: str) -> pd.DataFrame:
    df: pd.DataFrame = pd.read_csv(file_name, sep='|')
    df = df.loc[:, ~df.columns.str.contains('^Unnamed')]
    df = df.iloc[1:]
    df.reset_index(drop=True, inplace=True)
    df.columns = [x.replace(" ", "") for x in df.columns]
    df = df.applymap(lambda x: x.strip() if isinstance(x, str) else x)

    if df.empty:
        raise ValueError("No storage layout found in file")

    return df


def print_new_slots(df: pd.DataFrame):
    new = df[df["Name_r"].isnull()][["Name_l", "Type_l",
                                     "Slot", "Offset", "Bytes_l"]]
    if not new.empty:
        new.columns = NEW_DISPLAY_COLS
        print("\n New or shifted storage slots:")
        print(new.to_string(index=False))
    else:
        print("No new or shifted storage slots")


def print_collisions(df: pd.DataFrame):
    collisions = df[(df["Name_r"].notnull()) & (
        df["Type_l"] != df["Type_r"])].copy()

    if not collisions.empty:
        collisions.drop(columns=["Contract_l", "Contract_r"], inplace=True)
        collisions.columns = COLLISION_DISPLAY_COLS
        print("\n Potential storage collisions:")
        print(collisions.to_string(index=False))
    else:
        print("No potential storage collisions")


def main():
    # Fetch the local and remote forge inspect output files
    local, remote = parse_args()

    # Read the forge inspect output files into dataframes
    df_local = read_forge_inspect_output(local)
    df_remote = read_forge_inspect_output(remote)

    # Join the dataframes on the slot and offset columns
    result = pd.merge(df_local, df_remote, how="left", on=["Slot", "Offset"], suffixes=('_l', '_r'))

    # New storage slots
    print_new_slots(result)

    # Potential storage collisions
    print_collisions(result)


if __name__ == "__main__":
    main()
