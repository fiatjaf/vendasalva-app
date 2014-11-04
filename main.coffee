React     = require 'react'
Reactable = require 'Reactable'
dayParser = require('./parser/dia.js').parse
store     = require './store.coffee'

{div, span, pre,
 small, i, p, a, button,
 h1, h2, h3, h4,
 form, legend, fieldset, input, textarea, select,
 table, thead, tbody, tfoot, tr, th, td,
 ul, li} = React.DOM

Main = React.createClass
  displayName: 'Main'
  reset: (e) ->
    e.preventDefault()
    store.reset().then(-> location.reload())
  render: ->
    (div {id: 'main'},
      (button
        onClick: @reset
      , 'RESET')
      (Dashboard {})
    )

Dashboard = React.createClass
  displayName: 'Dashboard'

  getInitialState: ->
    facts: []

  render: ->
    vendas = []
    compras = []
    contas = []
    comments = []
    caixa = [{desc: 'Vendas', value: 0}]
    caixa.saldo = 0
    receita = 0
    for fact in @state.facts
      fact.value = parseFloat(fact.value) or 0

      switch fact.kind
        when 'venda'
          vendas.push fact
          caixa[0].value += fact.value if fact.pagamento == 'dinheiro'
          caixa.saldo += fact.value
          receita += fact.value
        when 'compra' then compras.push fact
        when 'conta'
          contas.push fact
        when 'entrada'
          caixa.push fact
          caixa.saldo += fact.value
        when 'saída'
          fact.value = -fact.value
          caixa.push fact
          caixa.saldo += fact.value
        when 'comment' then comments.push fact

    (div className: 'dashboard',
      (div className: 'half',
        (Day
          day: (new Date).toISOString().split('T')[0]
          onChange: @dayChanged
        )
      )
      (div className: 'half',
        (div className: 'facts',
          (div className: 'vendas',
            (h2 {}, 'Vendas')
            (h4 {}, "Total: #{receita}")
            (Reactable.Table data: vendas)
          ) if vendas.length
          (div className: 'compras',
            (h2 {}, 'Compras')
            (ul {},
              (li {key: i},
                (h3 {}, compra.fornecedor)
                (Reactable.Table data: compra.items)
                (div {},
                  "+ #{extra.desc}: #{extra.value}"
                ) for extra in compra.extras if compra.extras
                (div {}, "Total: #{compra.total}") if compra.total
              ) for compra, i in compras
            )
          ) if compras.length
          (div className: 'contas',
            (h2 {}, 'Pagamentos')
            (Reactable.Table data: contas)
          ) if contas.length
          (div className: 'caixa',
            (h2 {}, 'Caixa')
            (table {},
              (thead {},
                (tr {},
                  (th {})
                  (th {}, 'Saídas')
                  (th {}, 'Entradas')
                )
              )
              (tbody {},
                (tr {},
                  (td {}, row.desc)
                  (td {}, if row.value < 0 then row.value else null)
                  (td {}, if row.value > 0 then row.value else null)
                ) for row in caixa
              )
              (tfoot {},
                (tr {},
                  (th {colSpan: 3}, caixa.saldo)
                )
              )
            )
          )
          (div className: 'notas',
            (h2 {}, 'Anotações')
            (pre {key: Math.random()}, c.note) for c in comments
          ) if comments.length
        )
      )
    )

  dayChanged: (facts) ->
    @setState facts: facts

Day = React.createClass
  displayName: 'Day'

  getInitialState: ->
    raw: ''
    parsed: {}
    failure: false

  componentDidMount: ->
    if @props.day
      store.get('day:' + @props.day).then (doc) =>
        @setState raw: doc.raw

  render: ->
    (div className: 'day',
      (textarea
        value: @state.raw
        onChange: @handleChange
      )
    )

  handleChange: (e) ->
    try
      parsed = dayParser e.target.value
      failure = false
      @props.onChange parsed if @props.onChange
    catch x
      console.log x
      parsed = @state.parsed
      failure = true

    @setState
      raw: e.target.value
      parsed: parsed
      failure: failure

React.renderComponent Main(), document.body

















