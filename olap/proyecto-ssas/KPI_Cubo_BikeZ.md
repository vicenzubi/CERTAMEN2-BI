# KPI del cubo "Cubo Ventas BikeZ" (pestaña **KPIs** en Visual Studio)

Cada KPI se crea con el botón **New KPI** de la pestaña *KPIs* del cubo. Copie en cada campo el texto indicado (sin comillas de bloque). Los indicadores de estado devuelven 1 (bien), 0 (alerta) o -1 (mal) y se muestran con el gráfico de estado elegido.

> Las metas son **referenciales** y fueron definidas por el equipo para la demostración; la gerencia de Bike Z puede ajustarlas en el futuro sin cambiar el modelo.

---

## KPI 1 · Crecimiento de Ingresos

| Campo | Valor |
|---|---|
| Name | `KPI1 Crecimiento Ingresos` |
| Associated measure group | `Ventas` |
| Value Expression | `[Measures].[Crecimiento Interanual]` |
| Goal Expression | `0.10` |
| Status indicator | Gauge (o Traffic light) |
| Trend indicator | Standard arrow |

**Status Expression**
```mdx
CASE
    WHEN IsEmpty(KPIValue("KPI1 Crecimiento Ingresos")) THEN NULL
    WHEN KPIValue("KPI1 Crecimiento Ingresos") >= KPIGoal("KPI1 Crecimiento Ingresos") THEN 1
    WHEN KPIValue("KPI1 Crecimiento Ingresos") >= 0 THEN 0
    ELSE -1
END
```

**Trend Expression**
```mdx
CASE
    WHEN IsEmpty([Measures].[Crecimiento vs Periodo Anterior]) THEN NULL
    WHEN [Measures].[Crecimiento vs Periodo Anterior] > 0 THEN 1
    WHEN [Measures].[Crecimiento vs Periodo Anterior] = 0 THEN 0
    ELSE -1
END
```

---

## KPI 2 · Tiempo Promedio de Despacho

| Campo | Valor |
|---|---|
| Name | `KPI2 Tiempo Despacho` |
| Associated measure group | `Ventas` |
| Value Expression | `[Measures].[Tiempo Promedio Despacho]` |
| Goal Expression | `7` |
| Status indicator | Traffic light |
| Trend indicator | Standard arrow |

**Status Expression** (menos días es mejor)
```mdx
CASE
    WHEN IsEmpty(KPIValue("KPI2 Tiempo Despacho")) THEN NULL
    WHEN KPIValue("KPI2 Tiempo Despacho") <= KPIGoal("KPI2 Tiempo Despacho") THEN 1
    WHEN KPIValue("KPI2 Tiempo Despacho") <= KPIGoal("KPI2 Tiempo Despacho") * 1.10 THEN 0
    ELSE -1
END
```

**Trend Expression** (baja de días = tendencia positiva)
```mdx
CASE
    WHEN IsEmpty(( [Measures].[Tiempo Promedio Despacho], [Fecha Pedido].[Calendario].CurrentMember.PrevMember )) THEN NULL
    WHEN [Measures].[Tiempo Promedio Despacho]
         < ( [Measures].[Tiempo Promedio Despacho], [Fecha Pedido].[Calendario].CurrentMember.PrevMember ) THEN 1
    WHEN [Measures].[Tiempo Promedio Despacho]
         = ( [Measures].[Tiempo Promedio Despacho], [Fecha Pedido].[Calendario].CurrentMember.PrevMember ) THEN 0
    ELSE -1
END
```

---

## KPI 3 · Volumen por Categoría

| Campo | Valor |
|---|---|
| Name | `KPI3 Volumen Categoria` |
| Associated measure group | `Ventas` |
| Value Expression | `[Measures].[Unidades Vendidas]` |
| Goal Expression | `[Measures].[Unidades Año Anterior] * 1.10` |
| Status indicator | Traffic light |
| Trend indicator | Standard arrow |

**Status Expression**
```mdx
CASE
    WHEN IsEmpty(KPIGoal("KPI3 Volumen Categoria")) OR KPIGoal("KPI3 Volumen Categoria") = 0 THEN NULL
    WHEN KPIValue("KPI3 Volumen Categoria") >= KPIGoal("KPI3 Volumen Categoria") THEN 1
    WHEN KPIValue("KPI3 Volumen Categoria") >= [Measures].[Unidades Año Anterior] THEN 0
    ELSE -1
END
```

**Trend Expression**
```mdx
CASE
    WHEN IsEmpty([Measures].[Unidades Año Anterior]) THEN NULL
    WHEN [Measures].[Unidades Vendidas] > [Measures].[Unidades Año Anterior] THEN 1
    WHEN [Measures].[Unidades Vendidas] = [Measures].[Unidades Año Anterior] THEN 0
    ELSE -1
END
```

---

## KPI 4 · Ticket Promedio por Vendedor

| Campo | Valor |
|---|---|
| Name | `KPI4 Ticket Promedio` |
| Associated measure group | `Ventas` |
| Value Expression | `[Measures].[Ticket Promedio]` |
| Goal Expression | `[Measures].[Ticket Promedio Fuerza Ventas]` |
| Status indicator | Traffic light |
| Trend indicator | Standard arrow |

**Status Expression** (sobre el promedio de la fuerza de ventas = bien; hasta 20 % bajo = alerta)
```mdx
CASE
    WHEN IsEmpty(KPIValue("KPI4 Ticket Promedio")) THEN NULL
    WHEN KPIValue("KPI4 Ticket Promedio") >= KPIGoal("KPI4 Ticket Promedio") THEN 1
    WHEN KPIValue("KPI4 Ticket Promedio") >= KPIGoal("KPI4 Ticket Promedio") * 0.80 THEN 0
    ELSE -1
END
```

**Trend Expression**
```mdx
CASE
    WHEN [Fecha Pedido].[Calendario].CurrentMember.Level.Ordinal = 0 THEN NULL
    WHEN IsEmpty(( [Measures].[Ticket Promedio], ParallelPeriod([Fecha Pedido].[Calendario].[Año], 1, [Fecha Pedido].[Calendario].CurrentMember) )) THEN NULL
    WHEN [Measures].[Ticket Promedio]
         > ( [Measures].[Ticket Promedio], ParallelPeriod([Fecha Pedido].[Calendario].[Año], 1, [Fecha Pedido].[Calendario].CurrentMember) ) THEN 1
    ELSE -1
END
```

---

### Cómo verlos
Después de **Deploy**, en la pestaña *KPIs* presione **Browser View** (ícono de lupa). Arrastre, por ejemplo, `Fecha Pedido > Calendario > Año = 2017` al filtro superior: verá valor, meta, estado y tendencia de los cuatro KPI.
