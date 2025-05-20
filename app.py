from flask import Flask, jsonify
from kubernetes import client, config
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return 'Welcome to the Barkuni API!'

@app.route('/health')
def health():
    return jsonify(status="ok")

@app.route('/pods')
def list_pods():
    try:
        # Load in-cluster config if available, otherwise fall back to kubeconfig
        if os.getenv('KUBERNETES_SERVICE_HOST'):
            config.load_incluster_config()
        else:
            config.load_kube_config()
        v1 = client.CoreV1Api()
        pods = v1.list_namespaced_pod('kube-system')
        pod_names = [p.metadata.name for p in pods.items]
        return jsonify(pod_names)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)