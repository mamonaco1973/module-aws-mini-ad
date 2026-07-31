#!/usr/bin/python3
from flask import Flask, jsonify, Response
import subprocess

app = Flask(__name__)

# Path to Samba's auto-generated CA cert. This is PUBLIC (it only lets a client
# verify the DC's LDAPS cert), so it is safe to serve unauthenticated — clients
# fetch it at boot to trust ldaps:// for SSSD ldap-provider integration.
CA_PEM_PATH = "/var/lib/samba/private/tls/ca.pem"

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
        return max(values) if values else 0
    except Exception as e:
        return None

@app.route("/nextids", methods=["GET"])
def next_ids():
    max_uid = get_max_value("uidNumber")
    max_gid = get_max_value("gidNumber")

    next_uid = max_uid + 1 if isinstance(max_uid, int) else None
    next_gid = max_gid + 1 if isinstance(max_gid, int) else None

    return jsonify({
        "max_uidNumber": max_uid,
        "next_uidNumber": next_uid,
        "max_gidNumber": max_gid,
        "next_gidNumber": next_gid
    })

@app.route("/ca.pem", methods=["GET"])
def ca_pem():
    # Serve Samba's public CA cert so LDAP-mode clients can trust ldaps://.
    try:
        with open(CA_PEM_PATH, "r") as f:
            return Response(f.read(), mimetype="application/x-pem-file")
    except Exception:
        return Response("ca.pem not available\n", status=503,
                        mimetype="text/plain")


if __name__ == "__main__":
    # Run on all interfaces, port 80
    app.run(host="0.0.0.0", port=80)
