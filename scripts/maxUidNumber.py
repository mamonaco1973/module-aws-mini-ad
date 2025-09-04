#!/usr/bin/env python3
from flask import Flask, jsonify
import subprocess

app = Flask(__name__)

def get_max_value(attr):
    try:
        # Run ldbsearch to extract all values of the attribute
        result = subprocess.check_output(
            ["ldbsearch", "-H", "/var/lib/samba/private/sam.ldb",
             f"({attr}=*)", attr],
            stderr=subprocess.DEVNULL,
            text=True
        )
        # Parse and extract numbers
        values = [
            int(line.split(":")[1].strip())
            for line in result.splitlines()
            if line.startswith(f"{attr}:")
        ]
        return max(values) if values else None
    except Exception as e:
        return f"Error: {e}"

@app.route("/maxids", methods=["GET"])
def max_ids():
    max_uid = get_max_value("uidNumber")
    max_gid = get_max_value("gidNumber")
    return jsonify({"max_uidNumber": max_uid, "max_gidNumber": max_gid})

if __name__ == "__main__":
    # Run on all interfaces, port 80
    app.run(host="0.0.0.0", port=80)
