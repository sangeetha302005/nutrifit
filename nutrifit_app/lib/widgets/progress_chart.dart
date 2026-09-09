import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ProgressChart extends StatelessWidget {
  const ProgressChart({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [
                FlSpot(0, 72),
                FlSpot(1, 71.5),
                FlSpot(2, 71.2),
                FlSpot(3, 70.9),
                FlSpot(4, 70.4),
                FlSpot(5, 69.9),
              ],
              isCurved: true,
              color: Colors.greenAccent,
              barWidth: 4,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.greenAccent.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
