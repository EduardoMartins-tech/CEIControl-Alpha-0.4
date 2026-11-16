<?php
require_once __DIR__ . '/../models/ServicoModel.php';

class ServicoController {
    private $model;

    public function __construct($conn) {
        $this->model = new ServicoModel($conn);
    }

    public function listar() {
        return $this->model->listarTodos();
    }

    public function buscar($id) {
        return $this->model->buscarPorId($id);
    }

    public function cadastrar($nome, $descricao, $preco) {
        $this->model->criar($nome, $descricao, $preco);
        header("Location: /produtos?msg=servico_cadastrado");
        exit;
    }

    public function atualizar($id, $nome, $descricao, $preco) {
        $this->model->atualizar($id, $nome, $descricao, $preco);
        header("Location: /produtos?msg=servico_editado");
        exit;
    }

    public function excluir($id) {
        $this->model->excluir($id);
        header("Location: /produtos?msg=servico_excluido");
        exit;
    }
}
?>
