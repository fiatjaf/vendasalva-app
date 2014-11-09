Reais        = require 'reais'
Titulo       = require('titulo').toLaxTitleCase
dayParser    = require('./parser/dia.js').parse
store        = require './store.coffee'

{div, span, pre, nav,
 small, i, p, a, button,
 h1, h2, h3, h4,
 form, legend, fieldset, input, textarea, select,
 table, thead, tbody, tfoot, tr, th, td,
 ul, li} = React.DOM

Main = React.createClass
  displayName: 'Main'
  getInitialState: ->
    day: (new Date).toISOString().split('T')[0]
    Chosen: Input
    couchURL: localStorage.getItem('couchURL') or ''

  reset: (e) ->
    e.preventDefault()
    store.reset().then(-> location.reload())

  render: ->
    (div {id: 'main'},
      (nav {},
        (div className: 'menu',
          (a
            href: '#'
            onClick: @jumpTo('Input')
          , 'Lançamentos')
          (a
            href: '#'
            onClick: @jumpTo('Dias')
          , 'Dias')
        )
        (button
          onClick: @reset
          className: 'warning'
        , 'RESET')
        (input
          onChange: @updateCouchURL
          value: @state.couchURL
        )
        (button
          onClick: @sync
        , 'SYNC')
      )
      (Search
        onItemSelected: @jumpTo('Prices')
      )
      (div id: 'container',
        (@state.Chosen
          day: @state.day
          onDaySelected: @jumpTo('Input')
          item: @state.item
        )
      )
    )

  jumpTo: (choice) ->
    choices =
      'Input': Input
      'Dias': Dias
      'Prices': Prices
    (e) =>
      e.preventDefault() if e and e.preventDefault

      state = {Chosen: choices[choice]}
      if choice == 'Input' and typeof e == 'string'
        state.day = e
      if choice == 'Prices' and typeof e == 'string'
        state.item = e

      @setState state

  updateCouchURL: (e) -> @setState couchURL: e.target.value
  sync: (e) ->
    e.preventDefault()
    syncing = store.sync(@state.couchURL)
    console.log 'replication started'
    syncing.on 'change', (info) -> console.log 'change', info
    syncing.on 'error', (info) -> console.log 'error', info
    syncing.on 'complete', (info) =>
      console.log 'replication complete', info
      localStorage.setItem 'couchURL', @state.couchURL

Search = React.createClass
  displayName: 'Search'
  getInitialState: ->
    opts: []

  componentDidMount: ->
    @items = lunr ->
      this.use lunr.pt
      this.field 'item'
      this.ref 'item'

    store.listItems().then((items) =>
      @items.add({item: item}) for item in items
    )

  render: ->
    (div id: 'search',
      (Autocomplete.Combobox
        onInput: @handleInput
        onSelect: @handleSelect
      ,
        (Autocomplete.Option
          key: opt.ref
          value: opt.ref
          label: opt.ref
        ,
          (div {}, opt.ref)
        ) for opt in @state.opts
      )
    )

  handleInput: (input) ->
    items = @items.search(input)
    @setState opts: items

  handleSelect: (value) ->
    @setState opts: []
    @props.onItemSelected value

Prices = React.createClass
  displayName: 'Prices'
  getInitialState: ->
    prices: []

  componentDidMount: -> @updatePrices(@props.item)
  componentWillReceiveProps: (nextProps) -> @updatePrices(nextProps.item)

  updatePrices: (item) -> store.listPrices(item).then((prices) => @setState prices: prices)

  render: ->
    (table id: 'prices',
      (tbody {},
        (tr {},
          (td {},
           (a
             href: "##{price.id}"
             onClick: @dayClicked.bind @, price.id
           , price.day)
          )
          (td {}, price.name)
          (td {}, 'R$ ' + Reais.fromInteger price.price)
          (td {}, if price.compra then '(preço de compra)' else '')
        ) for price in @state.prices
      )
    )

  dayClicked: (id, e) ->
    e.preventDefault()
    @props.onDaySelected id

Input = React.createClass
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
          vendas.push {
            'Quant': fact.q
            'Produto': "#{Titulo fact.item} (#{fact.u})"
            'Valor pago': 'R$ ' + Reais.fromInteger fact.value
            'Forma de pagamento': fact.pagamento + if fact.x then " (#{fact.x}x)" else ''
          }
          caixa[0].value += fact.value if fact.pagamento == 'dinheiro'
          caixa.saldo += fact.value
          receita += fact.value
        when 'compra'
          compra = fact
          comprados = compra.items or []
          compra.items = []
          for item in comprados
            compra.items.push {
              'Quant': item.q
              'Produto': "#{Titulo item.item} (#{item.u})"
              'Preço total': 'R$ ' + Reais.fromInteger item.value
              'Preço unitário': 'R$ ' + Reais.fromInteger item.value/item.q
            }
          compras.push compra
        when 'conta'
          contas.push {
            'Conta': fact.desc
            'Valor': 'R$ ' + Reais.fromInteger fact.value
          }
        when 'entrada'
          caixa.push fact
          caixa.saldo += fact.value
        when 'saída'
          fact.value = -fact.value
          caixa.push fact
          caixa.saldo += fact.value
        when 'comment' then comments.push fact

    (div className: 'dashboard',
      (div className: 'full',
        (h1 {},
          if (new Date).toISOString().split('T')[0] == @props.day then 'Hoje, ' else ''
          @props.day.split('-').reverse().join('/')
        )
      )
      (div className: 'half',
        (Day
          day: @props.day
          onChange: @dayChanged
        )
      )
      (div className: 'half',
        (div className: 'facts',
          (div className: 'vendas',
            (h2 {}, 'Vendas')
            (h3 {}, "Total: R$ #{Reais.fromInteger receita}")
            (Reactable.Table
              data: vendas
              columns: ['Quant','Produto','Valor pago','Forma de pagamento']
              sortable: true
            )
          ) if vendas.length
          (div className: 'compras',
            (h2 {}, 'Compras')
            (ul {},
              (li {key: i},
                (h3 {}, Titulo compra.fornecedor)
                (Reactable.Table
                  data: compra.items
                  columns: ['Quant', 'Produto', 'Preço total', 'Preço unitário']
                  sortable: true
                )
                (div {ref: j},
                  "+ #{Titulo extra.desc}: R$ #{Reais.fromInteger extra.value}"
                ) for extra, j in compra.extras if compra.extras
                (h4 {}, "Total: R$ #{Reais.fromInteger compra.total}") if compra.total
              ) for compra, i in compras
            )
          ) if compras.length
          (div className: 'contas',
            (h2 {}, 'Pagamentos')
            (Reactable.Table
              data: contas
              columns: ['Conta', 'Valor']
              sortable: true
            )
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
                (tr {ref: i},
                  (td {}, Titulo row.desc)
                  (td {}, if row.value < 0 then 'R$ ' + Reais.fromInteger row.value else null)
                  (td {}, if row.value > 0 then 'R$ ' + Reais.fromInteger row.value else null)
                ) for row, i in caixa
              )
              (tfoot {},
                (tr {},
                  (th {colSpan: 3}, 'R$ ' + Reais.fromInteger caixa.saldo)
                )
              )
            )
          )
          (div className: 'notas',
            (h2 {}, 'Anotações')
            (pre {key: i}, c.note) for c, i in comments
          ) if comments.length
        )
      )
    )

  dayChanged: (facts) ->
    @setState facts: facts

Day = React.createClass
  displayName: 'Day'

  getInitialState: ->
    raw: localStorage.getItem @props.day + ':raw'
    rev: localStorage.getItem @props.day + ':rev'
    parsed: {}
    failure: false

  componentDidMount: ->
    if @props.day
      store.get(@props.day).then (doc) =>
        return if not doc
        if not localStorage.getItem(@props.day + ':rev') or
           doc._rev > localStorage.getItem(@props.day + ':rev')
          @setState rev: doc._rev
        @parse doc.raw

  parse: (raw) ->
    try
      parsed = dayParser raw
      failure = false
      @props.onChange parsed if @props.onChange
    catch x
      console.log x
      parsed = @state.parsed
      failure = true

    @setState
      raw: raw
      parsed: parsed
      failure: failure

  render: ->
    (div className: 'day',
      (textarea
        value: @state.raw
        onChange: @handleChange
      )
      (button
        onClick: @save
      , 'Salvar')
    )

  handleChange: (e) ->
    localStorage.setItem @props.day + ':raw', e.target.value
    localStorage.setItem @props.day + ':rev', @state.rev if @state.rev
    @parse e.target.value

  save: (e) ->
    e.preventDefault() if e
    doc = {_id: @props.day, raw: @state.raw}
    if @state.rev
      doc._rev = @state.rev
    store.save(doc).then((res) =>
      @setState rev: res.rev
      localStorage.removeItem(@props.day + ':raw')
      localStorage.removeItem(@props.day + ':rev')
    )

Dias = React.createClass
  displayName: 'Dias'
  getInitialState: ->
    days: []

  componentDidMount: ->
    store.listDays().then((days) =>
      @setState days: days
    )

  render: ->
    (table id: 'dias',
      (thead {},
        (tr {},
          (th {}, 'Dia')
          (th {}, 'Total vendido')
        )
      )
      (tbody {},
        (tr {ref: day},
          (td {},
            (a
              href: "##{day.day}"
              onClick: @goToDay(day.day)
            , "#{day.day.split('-').reverse().join('/')}")
          )
          (td {}, "R$ #{Reais.fromInteger day.receita}")
        ) for day in @state.days
      )
    )

  goToDay: (day) -> (e) =>
    e.preventDefault()
    @props.onDaySelected day

React.renderComponent Main(), document.body

















