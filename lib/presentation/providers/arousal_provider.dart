import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/arousal/arousal_service.dart';
import '../../data/arousal/model_state_loader.dart';
import '../../domain/models/arousal_sample.dart';
import '../../domain/models/eeg_sample.dart';
import '../../domain/models/band_power_sample.dart';
import 'device_provider.dart';

/// Provider for ArousalAnalysisService instance
final arousalAnalysisServiceProvider = Provider<ArousalService>((ref) {
  return ArousalService();
});

/// Provider for ModelStateLoader instance
final modelStateLoaderProvider = Provider<ModelStateLoader>((ref) {
  return ModelStateLoader();
});

/// Provider for loaded GMM model state
final arousalModelStateProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final loader = ref.watch(modelStateLoaderProvider);
  return await loader.getModelState();
});

/// Helper function to create arousal stream from EEG stream
Stream<ArousalSample> _createArousalStream(
  Stream<EegSample> eegStream,
  ArousalService service,
) async* {
  final buffer = <EegSample>[];
  final targetBufferSize = (AppConstants.eegSampleRate * 2).round(); // 512 samples
  
  await for (final eegSample in eegStream) {
    buffer.add(eegSample);
    
    // When buffer reaches 2 seconds, analyze and emit result
    if (buffer.length >= targetBufferSize) {
      try {
        // Make a copy of the buffer for analysis
        final windowSamples = List<EegSample>.from(buffer);
        
        // Analyze the window
        final result = await service.analyzeEegWindow(windowSamples);
        
        // Clear buffer for next window (keep last 256 samples for overlap if needed)
        // For now, clear entirely for 2-second windows
        buffer.clear();
        
        // Yield result
        yield result;
      } catch (e) {
        print('Error analyzing arousal window: $e');
        buffer.clear(); // Clear buffer on error
        // Optionally yield an error sample or skip
      }
    }
  }
}

/// Helper function to extract average band power from a sample
double _avgChannelBand(BandPowerSample s, String band) {
  double sum = 0;
  switch (band) {
    case 'alpha':
      sum = s.tp9.alphaAbsolute + s.af7.alphaAbsolute + 
            s.af8.alphaAbsolute + s.tp10.alphaAbsolute;
      break;
    case 'beta':
      sum = s.tp9.betaAbsolute + s.af7.betaAbsolute + 
            s.af8.betaAbsolute + s.tp10.betaAbsolute;
      break;
    case 'theta':
      sum = s.tp9.thetaAbsolute + s.af7.thetaAbsolute + 
            s.af8.thetaAbsolute + s.tp10.thetaAbsolute;
      break;
    case 'gamma':
      sum = s.tp9.gammaAbsolute + s.af7.gammaAbsolute + 
            s.af8.gammaAbsolute + s.tp10.gammaAbsolute;
      break;
    case 'delta':
      sum = s.tp9.deltaAbsolute + s.af7.deltaAbsolute + 
            s.af8.deltaAbsolute + s.tp10.deltaAbsolute;
      break;
  }
  return sum / 4.0;
}

/// Helper function to create arousal stream from band power stream
/// Uses improved normalization with wider expected ratio range
Stream<ArousalSample> _createArousalStreamFromBandPowers(
  Stream<BandPowerSample> bandPowerStream,
) async* {
  final buffer = <BandPowerSample>[];
  final targetBufferSize = 8; // ~2 seconds at 4Hz band power rate
  
  // Running statistics for adaptive normalization
  final arousalHistory = <double>[];
  double runningMin = double.infinity;
  double runningMax = double.negativeInfinity;
  
  await for (final sample in bandPowerStream) {
    buffer.add(sample);
    
    // When buffer reaches target size, compute arousal
    if (buffer.length >= targetBufferSize) {
      try {
        // Compute average band powers across buffer
        double avgAlpha = 0, avgBeta = 0, avgTheta = 0, avgGamma = 0, avgDelta = 0;
        int validSamples = 0;
        
        for (final s in buffer) {
          final alpha = _avgChannelBand(s, 'alpha');
          final beta = _avgChannelBand(s, 'beta');
          final theta = _avgChannelBand(s, 'theta');
          final gamma = _avgChannelBand(s, 'gamma');
          final delta = _avgChannelBand(s, 'delta');
          
          // Skip invalid samples (NaN or very low values indicating no signal)
          if (alpha.isNaN || beta.isNaN || theta.isNaN || gamma.isNaN ||
              (alpha + beta + theta + gamma + delta) < 0.001) {
            continue;
          }
          
          avgAlpha += alpha;
          avgBeta += beta;
          avgTheta += theta;
          avgGamma += gamma;
          avgDelta += delta;
          validSamples++;
        }
        
        // Only proceed if we have enough valid samples
        if (validSamples < targetBufferSize / 2) {
          buffer.clear();
          continue;
        }
        
        avgAlpha /= validSamples;
        avgBeta /= validSamples;
        avgTheta /= validSamples;
        avgGamma /= validSamples;
        avgDelta /= validSamples;
        
        // Compute total power for relative values
        final totalPower = avgDelta + avgTheta + avgAlpha + avgBeta + avgGamma;
        
        // Use relative band powers for more stable arousal calculation
        final relAlpha = totalPower > 0 ? avgAlpha / totalPower : 0.0;
        final relBeta = totalPower > 0 ? avgBeta / totalPower : 0.0;
        final relTheta = totalPower > 0 ? avgTheta / totalPower : 0.0;
        final relGamma = totalPower > 0 ? avgGamma / totalPower : 0.0;
        final relDelta = totalPower > 0 ? avgDelta / totalPower : 0.0;
        
        // Compute arousal ratio using relative powers
        // Higher beta/gamma relative to alpha/theta = higher arousal
        // Add delta to the denominator for stability (low frequency = relaxed)
        final denominator = relAlpha + relTheta + (relDelta * 0.5);
        final arousalRatio = denominator > 0.001 
            ? (relBeta + relGamma * 1.5) / denominator  // Weight gamma higher
            : 0.5;
        
        // Track running statistics for adaptive normalization
        if (arousalRatio.isFinite && arousalRatio > 0) {
          arousalHistory.add(arousalRatio);
          if (arousalHistory.length > 50) arousalHistory.removeAt(0);
          
          if (arousalRatio < runningMin) runningMin = arousalRatio;
          if (arousalRatio > runningMax) runningMax = arousalRatio;
        }
        
        // Normalize to 0-1 range using sigmoid transformation
        // This gives better distribution across the range
        double arousalIndex;
        
        if (arousalHistory.length >= 5) {
          // Use adaptive normalization based on observed data
          // Calculate mean and std for better scaling
          final mean = arousalHistory.reduce((a, b) => a + b) / arousalHistory.length;
          double variance = 0;
          for (final v in arousalHistory) {
            variance += (v - mean) * (v - mean);
          }
          final std = math.sqrt(variance / arousalHistory.length);
          
          if (std > 0.01) {
            // Z-score normalization then sigmoid
            final zScore = (arousalRatio - mean) / std;
            // Sigmoid that maps z=-2 to ~0.1 and z=+2 to ~0.9
            arousalIndex = 1.0 / (1.0 + math.exp(-zScore));
          } else {
            // Low variance - use range-based normalization
            final range = runningMax - runningMin;
            if (range > 0.01) {
              arousalIndex = ((arousalRatio - runningMin) / range).clamp(0.0, 1.0);
            } else {
              // Very narrow range - map to middle
              arousalIndex = 0.5;
            }
          }
        } else {
          // Initial samples - use sigmoid with empirical center
          // Center around 0.3 which is a typical resting ratio
          final centered = arousalRatio - 0.3;
          arousalIndex = 1.0 / (1.0 + math.exp(-centered * 4.0));
        }
        
        // Ensure arousal index is valid and has some spread
        if (!arousalIndex.isFinite) {
          arousalIndex = 0.5;
        }
        arousalIndex = arousalIndex.clamp(0.0, 1.0);
        
        // Determine label based on arousal index
        String label;
        if (arousalIndex < 0.33) {
          label = 'low';
        } else if (arousalIndex < 0.67) {
          label = 'medium';
        } else {
          label = 'high';
        }
        
        // Compute cluster probabilities using soft assignment
        // Use gaussian-like falloff from each center
        final lowCenter = 0.17;
        final medCenter = 0.5;
        final highCenter = 0.83;
        final sigma = 0.25;
        
        double lowProb = math.exp(-math.pow(arousalIndex - lowCenter, 2) / (2 * sigma * sigma));
        double medProb = math.exp(-math.pow(arousalIndex - medCenter, 2) / (2 * sigma * sigma));
        double highProb = math.exp(-math.pow(arousalIndex - highCenter, 2) / (2 * sigma * sigma));
        
        // Normalize probabilities
        final probSum = lowProb + medProb + highProb;
        lowProb /= probSum;
        medProb /= probSum;
        highProb /= probSum;
        
        buffer.clear();
        
        yield ArousalSample(
          timestamp: DateTime.now(),
          arousalIndex: arousalIndex,
          arousalLabel: label,
          confidence: validSamples >= targetBufferSize ? 0.8 : 0.6,
          confidenceMargin: (arousalIndex - 0.5).abs() * 2,
          clusterProbs: {
            'low': lowProb.clamp(0.0, 1.0),
            'medium': medProb.clamp(0.0, 1.0),
            'high': highProb.clamp(0.0, 1.0),
          },
        );
      } catch (e) {
        print('Error computing arousal from band powers: $e');
        buffer.clear();
      }
    }
  }
}

/// Stream provider for arousal analysis results
/// Uses band powers for more reliable real-time analysis
final arousalStreamProvider = StreamProvider.family<ArousalSample, String>((ref, deviceId) {
  final museService = ref.read(museServiceProvider);
  final bandPowerStream = museService.subscribeToBandPowers(deviceId);
  return _createArousalStreamFromBandPowers(bandPowerStream);
});
